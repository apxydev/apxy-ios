import Foundation

enum RecordDeliveryMode: Sendable {
    case buffered
    case immediate
}

struct CapturePayload: Sendable {
    let requestMethod: String
    let url: String
    let host: String
    let path: String
    let requestHeaders: [String: String]?
    let requestBody: Data?
    let requestBodySource: RequestBodyCaptureSource
    let requestBodySize: Int64?
    let requestContentType: String?
    let finalURL: String?
    let finalHost: String?
    let finalPath: String?
    let finalRequestHeaders: [String: String]?
    let statusCode: Int
    let responseHeaders: [String: String]?
    let responseBody: Data?
    let responseBodySize: Int64?
    let responseContentType: String?
    let redirectCount: Int
    let duration: Int64
    let tls: Bool
    let hadError: Bool
    let expectedResponseBodySize: Int64?
    let transferSize: TransferSizeInfo

    static func make(
        request: URLRequest,
        currentRequest: URLRequest,
        requestBody: Data?,
        requestBodySource: RequestBodyCaptureSource,
        response: HTTPURLResponse?,
        responseData: Data?,
        duration: Int64,
        redirectCount: Int,
        metrics: URLSessionTaskMetrics?,
        error: Error?
    ) -> CapturePayload? {
        guard let url = request.url,
              let host = url.host else {
            return nil
        }

        let transferSize = TransferSizeInfo(from: metrics)
        let requestBodySize = transferSize.requestBodyBytesBeforeEncoding
            ?? requestBody.map { Int64($0.count) }
            ?? contentLength(from: currentRequest)
        let expectedResponseBodySize = expectedResponseBodySize(from: response)
        let responseBodySize = transferSize.responseBodyBytesAfterDecoding
            ?? responseData.map { Int64($0.count) }
            ?? expectedResponseBodySize

        return CapturePayload(
            requestMethod: request.httpMethod ?? "GET",
            url: url.absoluteString,
            host: host,
            path: url.path.isEmpty ? "/" : url.path,
            requestHeaders: request.allHTTPHeaderFields.flatMap { $0.isEmpty ? nil : $0 },
            requestBody: requestBody,
            requestBodySource: requestBodySource,
            requestBodySize: requestBodySize,
            requestContentType: request.value(forHTTPHeaderField: "Content-Type"),
            finalURL: currentRequest.url?.absoluteString,
            finalHost: currentRequest.url?.host,
            finalPath: currentRequest.url?.path ?? (url.path.isEmpty ? "/" : url.path),
            finalRequestHeaders: currentRequest.allHTTPHeaderFields.flatMap { $0.isEmpty ? nil : $0 },
            statusCode: response?.statusCode ?? (error != nil ? -1 : 0),
            responseHeaders: response?.allHeaderFields.reduce(into: [String: String]()) { partialResult, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    partialResult[key] = value
                }
            },
            responseBody: responseData,
            responseBodySize: responseBodySize,
            responseContentType: response?.value(forHTTPHeaderField: "Content-Type"),
            redirectCount: redirectCount,
            duration: duration,
            tls: url.scheme == "https",
            hadError: error != nil,
            expectedResponseBodySize: expectedResponseBodySize,
            transferSize: transferSize
        )
    }

    private static func contentLength(from request: URLRequest) -> Int64? {
        guard let rawValue = request.value(forHTTPHeaderField: "Content-Length"),
              let contentLength = Int64(rawValue) else {
            return nil
        }

        return contentLength
    }

    private static func expectedResponseBodySize(from response: HTTPURLResponse?) -> Int64? {
        guard let response else { return nil }
        let expectedContentLength = response.expectedContentLength
        guard expectedContentLength >= 0 else { return nil }
        return expectedContentLength
    }
}

/// Actor-backed SDK runtime. Owns session lifecycle, buffered records, context,
/// and the current connection snapshot so records and metadata are captured from
/// one consistent state owner.
actor SessionManager {
    private let transport: any SessionTransporting
    private let recordTransport: any RecordTransport
    private let connectionStateTracker: ConnectionStateTracker
    private let sessionIdleTimeout: TimeInterval
    private let flushInterval: TimeInterval
    private let recordDeliveryMode: RecordDeliveryMode
    private let buffer: RecordBuffer

    private var context = SessionContext()
    private var currentSessionID: String?
    private var sdkClient: SDKClient?
    private var hasRegisteredClient = false
    private var backgroundedAt: Date?
    private var connectionSnapshot = ConnectionSnapshot.unknown
    private var isRunning = false
    private var flushTask: Task<Void, Never>?

    init(
        transport: any SessionTransporting,
        recordTransport: any RecordTransport,
        connectionStateTracker: ConnectionStateTracker,
        bufferCapacity: Int,
        recordDeliveryMode: RecordDeliveryMode,
        flushInterval: TimeInterval,
        sessionIdleTimeout: TimeInterval
    ) {
        self.transport = transport
        self.recordTransport = recordTransport
        self.connectionStateTracker = connectionStateTracker
        self.sessionIdleTimeout = sessionIdleTimeout
        self.flushInterval = max(1, flushInterval)
        self.recordDeliveryMode = recordDeliveryMode
        self.buffer = RecordBuffer(capacity: bufferCapacity)
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        await recordTransport.start()
        startFlushLoop()

        let client = ClientIdentity.build()
        sdkClient = client

        SDKLogger.debug("registerClient starting clientId=\(String(client.id.prefix(8)))")

        do {
            try await transport.registerClient(client)
            await connectionStateTracker.reportServerEndpointSuccess()
        } catch {
            SDKLogger.warn("cannot reach server (registerClient): \(error.localizedDescription)")
            await connectionStateTracker.reportServerEndpointFailure(reason: error.localizedDescription)
        }

        guard isRunning, !Task.isCancelled else { return }
        hasRegisteredClient = true
        await appDidBecomeActive()
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false

        flushTask?.cancel()
        flushTask = nil

        await flushBufferedRecords()
        await recordTransport.stop()

        context.reset()
        currentSessionID = nil
        sdkClient = nil
        hasRegisteredClient = false
        backgroundedAt = nil
        connectionSnapshot = .unknown
    }

    func updateConnection(_ snapshot: ConnectionSnapshot) {
        guard isRunning else { return }
        connectionSnapshot = snapshot
    }

    func appDidBecomeActive() async {
        guard isRunning, hasRegisteredClient else { return }

        if let backgroundedAt {
            let elapsed = Date().timeIntervalSince(backgroundedAt)
            self.backgroundedAt = nil

            if elapsed < sessionIdleTimeout {
                SDKLogger.debug(
                    "resumeSession elapsed=\(Int(elapsed))s timeout=\(Int(sessionIdleTimeout))s"
                )
                return
            }
        } else if let currentSessionID {
            SDKLogger.debug(
                "handleForeground: session \(currentSessionID.prefix(8)) already active, skipping duplicate"
            )
            return
        }

        await startNewSession()
    }

    func appDidEnterBackground() {
        guard isRunning else { return }
        backgroundedAt = Date()
    }

    func setUser(_ user: ApxyUser) async {
        guard isRunning else { return }
        context.setUser(user)
        await syncContextToActiveSession()
    }

    func setTag(key: String, value: String) async {
        guard isRunning else { return }
        context.setTag(key: key, value: value)
        await syncContextToActiveSession()
    }

    func setContext(key: String, value: ApxyContextValue) async {
        guard isRunning else { return }
        context.setContext(key: key, value: value)
        await syncContextToActiveSession()
    }

    func capture(_ payload: CapturePayload) async {
        guard isRunning else { return }

        let record = NetworkRecord(
            id: UUID().uuidString,
            timestamp: Date(),
            method: payload.requestMethod,
            url: payload.url,
            host: payload.host,
            path: payload.path,
            requestHeaders: payload.requestHeaders,
            requestBody: payload.requestBody,
            requestBodySource: payload.requestBodySource.rawValue,
            requestBodySize: payload.requestBodySize,
            requestContentType: payload.requestContentType,
            finalURL: payload.finalURL,
            finalHost: payload.finalHost,
            finalPath: payload.finalPath,
            finalRequestHeaders: payload.finalRequestHeaders,
            statusCode: payload.statusCode,
            responseHeaders: payload.responseHeaders,
            responseBody: payload.responseBody,
            responseBodySize: payload.responseBodySize,
            responseContentType: payload.responseContentType,
            redirectCount: payload.redirectCount,
            requestHeaderBytesSent: payload.transferSize.requestHeaderBytesSent,
            requestBodyBytesBeforeEncoding: payload.transferSize.requestBodyBytesBeforeEncoding,
            requestBodyBytesSent: payload.transferSize.requestBodyBytesSent,
            responseHeaderBytesReceived: payload.transferSize.responseHeaderBytesReceived,
            responseBodyBytesReceived: payload.transferSize.responseBodyBytesReceived,
            responseBodyBytesAfterDecoding: payload.transferSize.responseBodyBytesAfterDecoding,
            duration: payload.duration,
            tls: payload.tls,
            mocked: false,
            sessionID: currentSessionID
        )

        logCaptureDetails(
            record: record,
            requestBodySource: payload.requestBodySource,
            expectedResponseBodySize: payload.expectedResponseBodySize,
            hadError: payload.hadError
        )

        await dispatch(record)
    }

    func bufferedRecordCount() async -> Int {
        await buffer.count
    }

    private func startNewSession() async {
        guard isRunning, let sdkClient else { return }

        let sessionID = UUID().uuidString
        currentSessionID = sessionID

        SDKLogger.debug("createSession sessionId=\(String(sessionID.prefix(8)))")

        let clientContext = context.toClientContext(networkType: connectionSnapshot.networkType)
        do {
            try await transport.createSession(
                id: sessionID,
                clientID: sdkClient.id,
                context: clientContext
            )
            await connectionStateTracker.reportServerEndpointSuccess()
        } catch {
            SDKLogger.warn("cannot reach server (createSession): \(error.localizedDescription)")
            await connectionStateTracker.reportServerEndpointFailure(reason: error.localizedDescription)
        }
    }

    private func syncContextToActiveSession() async {
        guard isRunning, let currentSessionID else { return }

        let clientContext = context.toClientContext(networkType: connectionSnapshot.networkType)
        do {
            try await transport.updateSessionContext(
                id: currentSessionID,
                context: clientContext
            )
            await connectionStateTracker.reportServerEndpointSuccess()
        } catch {
            SDKLogger.warn("cannot reach server (updateSessionContext): \(error.localizedDescription)")
            await connectionStateTracker.reportServerEndpointFailure(reason: error.localizedDescription)
        }
    }

    private func dispatch(_ record: NetworkRecord) async {
        switch recordDeliveryMode {
        case .buffered:
            await buffer.append(record)
        case .immediate:
            do {
                try await recordTransport.send(records: [record])
            } catch {
                SDKLogger.warn(
                    "immediate transport send failed; buffering record for retry: \(error.localizedDescription)"
                )
                await buffer.append(record)
            }
        }
    }

    private func startFlushLoop() {
        flushTask?.cancel()
        flushTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: sleepNanoseconds(for: flushInterval))
                } catch {
                    break
                }

                await self.flushBufferedRecords()
            }
        }
    }

    private func flushBufferedRecords() async {
        let records = await buffer.drain()
        guard !records.isEmpty else { return }

        do {
            try await recordTransport.send(records: records)
        } catch {
            SDKLogger.warn(
                "record flush failed; re-buffering \(records.count) record(s): \(error.localizedDescription)"
            )
            await buffer.prepend(records)
        }
    }

    private func logCaptureDetails(
        record: NetworkRecord,
        requestBodySource: RequestBodyCaptureSource,
        expectedResponseBodySize: Int64?,
        hadError: Bool
    ) {
        let durationMs = Double(record.duration) / 1_000_000
        let formattedDuration = String(format: "%.2f", durationMs)
        SDKLogger.debug(
            "captured method=\(record.method) url=\(record.url) finalURL=\(record.finalURL ?? record.url) status=\(record.statusCode) redirects=\(record.redirectCount ?? 0) requestBodySource=\(requestBodySource.rawValue) requestBodyBytes=\(record.requestBodySize ?? Int64(record.requestBody?.count ?? 0)) responseBodyBytes=\(record.responseBodySize ?? Int64(record.responseBody?.count ?? 0)) durationMs=\(formattedDuration)"
        )

        if Self.isLikelyJSON(contentType: record.requestContentType), record.requestBody == nil {
            SDKLogger.warn(
                "captured JSON request without body method=\(record.method) url=\(record.url) source=\(requestBodySource.rawValue)"
            )
        }

        if Self.isLikelyJSON(contentType: record.responseContentType),
           record.responseBody == nil,
           hadError == false,
           let expectedResponseBodySize,
           expectedResponseBodySize > 0 {
            SDKLogger.warn(
                "captured JSON response without body method=\(record.method) url=\(record.url) expectedBytes=\(expectedResponseBodySize)"
            )
        }
    }

    private static func isLikelyJSON(contentType: String?) -> Bool {
        guard let contentType else { return false }
        let normalized = contentType.lowercased()
        return normalized.contains("json") || normalized.contains("+json")
    }
}

struct TransferSizeInfo: Sendable {
    let requestHeaderBytesSent: Int64?
    let requestBodyBytesBeforeEncoding: Int64?
    let requestBodyBytesSent: Int64?
    let responseHeaderBytesReceived: Int64?
    let responseBodyBytesReceived: Int64?
    let responseBodyBytesAfterDecoding: Int64?

    init(from metrics: URLSessionTaskMetrics?) {
        guard let metrics else {
            self = .empty
            return
        }

        self = metrics.transactionMetrics.reduce(.empty) { partialResult, transaction in
            partialResult.merging(TransferSizeInfo(transaction: transaction))
        }
    }

    static let empty = TransferSizeInfo(
        requestHeaderBytesSent: nil,
        requestBodyBytesBeforeEncoding: nil,
        requestBodyBytesSent: nil,
        responseHeaderBytesReceived: nil,
        responseBodyBytesReceived: nil,
        responseBodyBytesAfterDecoding: nil
    )

    init(
        requestHeaderBytesSent: Int64?,
        requestBodyBytesBeforeEncoding: Int64?,
        requestBodyBytesSent: Int64?,
        responseHeaderBytesReceived: Int64?,
        responseBodyBytesReceived: Int64?,
        responseBodyBytesAfterDecoding: Int64?
    ) {
        self.requestHeaderBytesSent = requestHeaderBytesSent
        self.requestBodyBytesBeforeEncoding = requestBodyBytesBeforeEncoding
        self.requestBodyBytesSent = requestBodyBytesSent
        self.responseHeaderBytesReceived = responseHeaderBytesReceived
        self.responseBodyBytesReceived = responseBodyBytesReceived
        self.responseBodyBytesAfterDecoding = responseBodyBytesAfterDecoding
    }

    init(transaction: URLSessionTaskTransactionMetrics) {
        requestHeaderBytesSent = transaction.countOfRequestHeaderBytesSent
        requestBodyBytesBeforeEncoding = transaction.countOfRequestBodyBytesBeforeEncoding
        requestBodyBytesSent = transaction.countOfRequestBodyBytesSent
        responseHeaderBytesReceived = transaction.countOfResponseHeaderBytesReceived
        responseBodyBytesReceived = transaction.countOfResponseBodyBytesReceived
        responseBodyBytesAfterDecoding = transaction.countOfResponseBodyBytesAfterDecoding
    }

    func merging(_ other: TransferSizeInfo) -> TransferSizeInfo {
        TransferSizeInfo(
            requestHeaderBytesSent: sum(requestHeaderBytesSent, other.requestHeaderBytesSent),
            requestBodyBytesBeforeEncoding: sum(requestBodyBytesBeforeEncoding, other.requestBodyBytesBeforeEncoding),
            requestBodyBytesSent: sum(requestBodyBytesSent, other.requestBodyBytesSent),
            responseHeaderBytesReceived: sum(responseHeaderBytesReceived, other.responseHeaderBytesReceived),
            responseBodyBytesReceived: sum(responseBodyBytesReceived, other.responseBodyBytesReceived),
            responseBodyBytesAfterDecoding: sum(responseBodyBytesAfterDecoding, other.responseBodyBytesAfterDecoding)
        )
    }

    private func sum(_ lhs: Int64?, _ rhs: Int64?) -> Int64? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            lhs &+ rhs
        case let (lhs?, nil):
            lhs
        case let (nil, rhs?):
            rhs
        case (nil, nil):
            nil
        }
    }
}

private func sleepNanoseconds(for duration: TimeInterval) -> UInt64 {
    UInt64(max(0, duration) * 1_000_000_000)
}

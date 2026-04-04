import Foundation

/// Actor-backed SDK runtime. Owns session lifecycle, buffered records, context,
/// and the current connection snapshot so records and metadata are captured from
/// one consistent state owner.
actor SessionManager {
    private let transport: any SessionTransporting
    private let recordTransport: any RecordTransport
    private let debugStore: ApxyDebugStore?
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
        debugStore: ApxyDebugStore? = nil,
        connectionStateTracker: ConnectionStateTracker,
        bufferCapacity: Int,
        recordDeliveryMode: RecordDeliveryMode,
        flushInterval: TimeInterval,
        sessionIdleTimeout: TimeInterval
    ) {
        self.transport = transport
        self.recordTransport = recordTransport
        self.debugStore = debugStore
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

    func capture(_ payload: CapturePayload, debugContext: DebugCaptureContext? = nil) async {
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

        if let debugStore, let debugContext {
            await debugStore.append(
                ApxyDebugRecord.make(
                    record: record,
                    metrics: debugContext.metrics,
                    error: debugContext.error
                )
            )
        }

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

private func sleepNanoseconds(for duration: TimeInterval) -> UInt64 {
    UInt64(max(0, duration) * 1_000_000_000)
}

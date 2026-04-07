import Foundation

/// Actor-backed SDK runtime. Owns session lifecycle, buffered records, context,
/// and the current connection snapshot so records and metadata are captured from
/// one consistent state owner.
actor SessionManager {
    private var transport: any SessionTransporting
    private var recordTransport: any RecordTransport
    private let debugStore: ApxyDebugStore?
    private let connectionStateTracker: ConnectionStateTracker
    private let sessionIdleTimeout: TimeInterval
    private var flushInterval: TimeInterval
    private var recordDeliveryMode: RecordDeliveryMode
    private let buffer: RecordBuffer

    private var context = SessionContext()
    private var currentSessionID: String?
    private var currentServerURL: String?
    private var sdkClient: SDKClient?
    private var hasRegisteredClient = false
    private var backgroundedAt: Date?
    private var connectionSnapshot = ConnectionSnapshot.unknown
    private var isRunning = false
    private var flushTask: Task<Void, Never>?
    private var scheduledFlushTask: Task<Void, Never>?
    private var activeFlushTask: Task<Void, Never>?
    private var flushRequestedWhileActive = false
    private var contextSyncTask: Task<Void, Never>?

    init(
        transport: any SessionTransporting,
        recordTransport: any RecordTransport,
        debugStore: ApxyDebugStore? = nil,
        serverURL: String?,
        connectionStateTracker: ConnectionStateTracker,
        bufferCapacity: Int,
        recordDeliveryMode: RecordDeliveryMode,
        flushInterval: TimeInterval,
        sessionIdleTimeout: TimeInterval
    ) {
        self.transport = transport
        self.recordTransport = recordTransport
        self.debugStore = debugStore
        self.currentServerURL = serverURL
        self.connectionStateTracker = connectionStateTracker
        self.sessionIdleTimeout = sessionIdleTimeout
        self.flushInterval = max(1, flushInterval)
        self.recordDeliveryMode = recordDeliveryMode
        self.buffer = RecordBuffer(capacity: bufferCapacity)
    }

    func reconfigure(
        transport: any SessionTransporting,
        recordTransport: any RecordTransport,
        serverURL: String?,
        recordDeliveryMode: RecordDeliveryMode,
        flushInterval: TimeInterval
    ) async {
        let normalizedFlushInterval = max(1, flushInterval)
        let oldRecordTransport = self.recordTransport
        let previousHasRegisteredClient = hasRegisteredClient
        let previousSessionID = currentSessionID

        guard isRunning else {
            self.transport = transport
            self.recordTransport = recordTransport
            self.currentServerURL = serverURL
            self.flushInterval = normalizedFlushInterval
            self.recordDeliveryMode = recordDeliveryMode
            return
        }
        flushTask?.cancel()
        flushTask = nil
        scheduledFlushTask?.cancel()
        scheduledFlushTask = nil
        contextSyncTask?.cancel()
        contextSyncTask = nil

        await finishPendingRecordFlushes()
        await oldRecordTransport.stop()

        self.transport = transport
        self.recordTransport = recordTransport
        self.currentServerURL = serverURL
        self.flushInterval = normalizedFlushInterval
        self.recordDeliveryMode = recordDeliveryMode

        await recordTransport.start()
        startFlushLoop()
        isRunning = true

        guard previousHasRegisteredClient else { return }
        guard let sdkClient else { return }
        do {
            try await transport.registerClient(sdkClient)
            await connectionStateTracker.reportServerEndpointSuccess()
            hasRegisteredClient = true
            currentSessionID = nil
            await startNewSession()
        } catch {
            SDKLogger.warn("cannot reach server (reconfigure): \(error.localizedDescription)")
            await connectionStateTracker.reportServerEndpointFailure(reason: error.localizedDescription)
            hasRegisteredClient = previousHasRegisteredClient
            currentSessionID = previousSessionID
        }
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
        scheduledFlushTask?.cancel()
        scheduledFlushTask = nil
        contextSyncTask?.cancel()
        contextSyncTask = nil

        if let activeFlushTask {
            await activeFlushTask.value
        }
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
        scheduleContextSync()
    }

    func setTag(key: String, value: String) async {
        guard isRunning else { return }
        context.setTag(key: key, value: value)
        scheduleContextSync()
    }

    func setContext(key: String, value: ApxyContextValue) async {
        guard isRunning else { return }
        context.setContext(key: key, value: value)
        scheduleContextSync()
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
        contextSyncTask?.cancel()
        contextSyncTask = nil

        let sessionID = UUID().uuidString
        let createdAt = Date()
        let name = Self.defaultSessionName(createdAt: createdAt)
        currentSessionID = sessionID

        SDKLogger.debug("createSession sessionId=\(String(sessionID.prefix(8)))")

        let clientContext = context.toClientContext(networkType: connectionSnapshot.networkType)
        if let debugStore {
            await debugStore.beginSession(
                id: sessionID,
                name: name,
                createdAt: createdAt,
                sdkClient: sdkClient,
                context: clientContext,
                serverURL: currentServerURL,
                isLiveManaged: currentServerURL != nil
            )
        }
        do {
            try await transport.createSession(
                id: sessionID,
                name: name,
                createdAt: createdAt,
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
        if let debugStore {
            await debugStore.updateSessionContext(
                id: currentSessionID,
                context: clientContext,
                serverURL: currentServerURL
            )
        }
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
        await buffer.append(record)

        switch recordDeliveryMode {
        case .buffered:
            break
        case .immediate:
            scheduleRecordFlush()
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

                self.scheduleRecordFlush()
            }
        }
    }

    private func scheduleRecordFlush(after delay: TimeInterval = 0) {
        guard isRunning else { return }

        if activeFlushTask != nil {
            flushRequestedWhileActive = true
            return
        }

        guard scheduledFlushTask == nil else { return }

        scheduledFlushTask = Task {
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: sleepNanoseconds(for: delay))
                } catch {
                    return
                }
            }

            await self.beginScheduledRecordFlush()
        }
    }

    private func beginScheduledRecordFlush() async {
        scheduledFlushTask = nil
        guard isRunning else { return }

        if activeFlushTask != nil {
            flushRequestedWhileActive = true
            return
        }

        activeFlushTask = Task {
            await self.performRecordFlushLoop()
        }
    }

    private func performRecordFlushLoop() async {
        while isRunning {
            flushRequestedWhileActive = false

            let records = await buffer.drain()
            guard !records.isEmpty else { break }

            do {
                try await recordTransport.send(records: records)
            } catch {
                SDKLogger.warn(
                    "record flush failed; re-buffering \(records.count) record(s): \(error.localizedDescription)"
                )
                await buffer.prepend(records)
                break
            }

            guard flushRequestedWhileActive else { break }
        }

        activeFlushTask = nil

        if isRunning, flushRequestedWhileActive {
            flushRequestedWhileActive = false
            scheduleRecordFlush()
        }
    }

    private func finishPendingRecordFlushes() async {
        scheduledFlushTask?.cancel()
        scheduledFlushTask = nil

        if let activeFlushTask {
            await activeFlushTask.value
        }

        await flushBufferedRecords()
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

    private func scheduleContextSync() {
        guard isRunning, currentSessionID != nil else { return }

        guard contextSyncTask == nil else { return }
        contextSyncTask = Task {
            await self.performScheduledContextSync()
        }
    }

    private func performScheduledContextSync() async {
        contextSyncTask = nil
        await syncContextToActiveSession()
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

    private static func defaultSessionName(createdAt: Date) -> String {
        sessionNameFormatter.string(from: createdAt)
    }
}

private func sleepNanoseconds(for duration: TimeInterval) -> UInt64 {
    UInt64(max(0, duration) * 1_000_000_000)
}

private let sessionNameFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "'SDK' yyyy-MM-dd HH:mm:ss"
    return formatter
}()

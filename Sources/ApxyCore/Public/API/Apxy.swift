import Foundation

/// APXY iOS SDK — captures URLSession traffic and streams it to a local APXY instance.
///
/// ## Quick start (local-only)
/// ```swift
/// import ApxyCore
/// Apxy.start()
/// ```
///
/// ## Send traffic to desktop APXY
/// ```swift
/// Apxy.start(serverURL: "http://192.168.1.5:8083")
/// ```
///
/// ## Full config
/// ```swift
/// Apxy.start(
///     options: ApxyOptions(debugConsole: .init(isEnabled: true))
/// )
/// Apxy.setUser(ApxyUser(id: "user-123", email: "dev@example.com"))
/// Apxy.setTag(key: "env", value: "staging")
/// Apxy.setContext(key: "subscription", value: ["plan": "pro"])
/// ```
public final class Apxy {
    private static let sharedLock = NSLock()
    nonisolated(unsafe) private static var shared: Apxy?

    private let sessionManager: SessionManager
    private let connectionMonitor: ConnectionMonitor
    private let connectionStateTracker: ConnectionStateTracker
    private var runtimeConfiguration: ApxyRuntimeConfiguration
    private var capturedDomains: [String]?
    private let transportMode: ApxyTransport
    private let webSocketMaxReconnectAttempts: Int
    private let webSocketReconnectCooldown: TimeInterval
    private let capturePolicy: ApxyCapturePolicy
    private let debugStore: ApxyDebugStore?
#if canImport(UIKit)
    private let lifecycleObserver: AppLifecycleObserver
#endif
    private var startupTask: Task<Void, Never>?

    private init(serverURL: URL?, options: ApxyOptions) {
        let onEvent = options.onConnectionEvent
        let connectionStateTracker = ConnectionStateTracker { event in
            guard let onEvent else { return }
            Task { @MainActor in
                onEvent(event)
            }
        }
        self.connectionStateTracker = connectionStateTracker

        let normalizedServerURL = Self.normalizeServerURL(serverURL)
        let normalizedFlushInterval = Self.normalizeFlushInterval(options.flushInterval)
        let normalizedCapturedDomains = Self.normalizeDomains(options.capturedDomains)

        self.runtimeConfiguration = ApxyRuntimeConfiguration(
            serverURL: normalizedServerURL?.absoluteString,
            flushInterval: normalizedFlushInterval,
            capturedDomains: normalizedCapturedDomains
        )
        self.capturePolicy = options.capturePolicy
        self.debugStore = options.debugConsole.isEnabled ? ApxyDebugStore(options: options.debugConsole) : nil
        self.transportMode = options.transport
        self.webSocketMaxReconnectAttempts = options.webSocketMaxReconnectAttempts
        self.webSocketReconnectCooldown = options.webSocketReconnectCooldown
        self.capturedDomains = normalizedCapturedDomains

        if normalizedServerURL != nil, options.debugConsole.isEnabled {
            SDKLogger.warn(
                "ApxyCore: remote transport and debugConsole are both enabled; this increases capture overhead"
            )
        }

        let (sessionTransport, recordTransport, deliveryMode) = Self.makeTransports(
            serverURL: normalizedServerURL,
            transportMode: transportMode,
            webSocketMaxReconnectAttempts: webSocketMaxReconnectAttempts,
            webSocketReconnectCooldown: webSocketReconnectCooldown,
            connectionStateTracker: connectionStateTracker
        )

        self.sessionManager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            debugStore: self.debugStore,
            serverURL: normalizedServerURL?.absoluteString,
            connectionStateTracker: connectionStateTracker,
            bufferCapacity: options.bufferSize,
            recordDeliveryMode: deliveryMode,
            flushInterval: normalizedFlushInterval,
            sessionIdleTimeout: options.sessionIdleTimeout
        )

        self.connectionMonitor = ConnectionMonitor { [sessionManager] snapshot in
            Task {
                await sessionManager.updateConnection(snapshot)
            }
        }
#if canImport(UIKit)
        self.lifecycleObserver = AppLifecycleObserver(
            onBecomeActive: { [sessionManager] in
                Task {
                    await sessionManager.appDidBecomeActive()
                }
            },
            onEnterBackground: { [sessionManager, debugStore] in
                Task {
                    await sessionManager.appDidEnterBackground()
                    if let debugStore {
                        await debugStore.flush()
                    }
                }
            }
        )
#endif

        let transportLabel: String
        if normalizedServerURL == nil {
            transportLabel = "local-only"
        } else {
            transportLabel = (deliveryMode == .immediate) ? "webSocket" : "http"
        }
        SDKLogger.debug(
            "started transport=\(transportLabel) bufferSize=\(options.bufferSize) flushInterval=\(normalizedFlushInterval)"
        )
    }

    /// Start the SDK in local-only mode. This convenience entry point enables the
    /// embedded debug console by default so `ApxyUI` can inspect captured traffic
    /// without extra configuration.
    public static func start(options: ApxyOptions = .init()) {
        var options = options
        if !options.debugConsole.isEnabled {
            options.debugConsole = .init(isEnabled: true)
        }

#if !DEBUG
        guard options.enableInRelease else {
            SDKLogger.debug("ApxyCore: disabled in Release build (set enableInRelease: true to override)")
            return
        }
#endif

        SDKLogger.level = options.logLevel

        let instance = Apxy(serverURL: nil, options: options)
        sharedLock.lock()
        defer { sharedLock.unlock() }
        guard shared == nil else { return }
        shared = instance
        instance.activate()
    }

    /// Start the SDK. Safe to call multiple times — subsequent calls are no-ops.
    public static func start(serverURL: String, options: ApxyOptions = .init()) {
#if !DEBUG
        guard options.enableInRelease else {
            SDKLogger.debug("ApxyCore: disabled in Release build (set enableInRelease: true to override)")
            return
        }
#endif

        guard let url = normalizeServerURL(serverURL) else {
            SDKLogger.warn("ApxyCore: invalid serverURL '\(serverURL)' — SDK not started")
            return
        }

        SDKLogger.level = options.logLevel

        let instance = Apxy(serverURL: url, options: options)
        sharedLock.lock()
        defer { sharedLock.unlock() }
        guard shared == nil else { return }
        shared = instance
        instance.activate()
    }

    /// Stop the SDK, flush remaining records, and release all resources.
    public static func stop() {
        let instance = detachShared()
        guard let instance else { return }

        instance.shutdown()
        SDKLogger.debug("stop: SDK stopped")
    }

    /// Apply runtime configuration without restarting the app process.
    ///
    /// Use this to modify server endpoint, flush interval, and captured domains
    /// while traffic capture is active.
    public static func reconfigure(_ configuration: ApxyRuntimeConfiguration) {
        guard let instance = activeInstance() else { return }
        instance.applyRuntimeConfiguration(configuration)
    }

    /// Returns the current runtime configuration for the active SDK instance.
    /// Values are session-only and not persisted.
    public static var activeRuntimeConfiguration: ApxyRuntimeConfiguration? {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        return shared?.runtimeConfiguration
    }

    /// Set the current authenticated user. Updates the session context immediately.
    public static func setUser(_ user: ApxyUser) {
        guard let instance = activeInstance() else { return }
        Task {
            await instance.sessionManager.setUser(user)
        }
    }

    /// Attach a key-value tag to the current session.
    public static func setTag(key: String, value: String) {
        guard let instance = activeInstance() else { return }
        Task {
            await instance.sessionManager.setTag(key: key, value: value)
        }
    }

    /// Attach a typed context value to the current session under the given key.
    public static func setContext(key: String, value: ApxyContextValue) {
        guard let instance = activeInstance() else { return }
        Task {
            await instance.sessionManager.setContext(key: key, value: value)
        }
    }

    /// Attach arbitrary JSON-like context to the current session under the given key.
    public static func setContext(key: String, value: Any) {
        guard let normalized = ApxyContextValue.make(from: value) else {
            SDKLogger.warn("ApxyCore: unsupported context value for key '\(key)'")
#if DEBUG
            assertionFailure("Unsupported APXY context value for key '\(key)'")
#endif
            return
        }

        setContext(key: key, value: normalized)
    }

    /// Returns the local embedded debug store when debug recording is enabled.
    public static var activeDebugStore: ApxyDebugStore? {
        activeInstance()?.debugStore
    }

    /// Returns persisted local sessions stored for the embedded debug console.
    public static func localSessions() async -> [ApxyLocalSession] {
        guard let store = activeInstance()?.debugStore else { return [] }
        return await store.localSessions()
    }

    /// Returns persisted local sessions that can be shared manually to APXY Core.
    public static func shareableLocalSessions() async -> [ApxyLocalSession] {
        guard let store = activeInstance()?.debugStore else { return [] }
        return await store.shareableLocalSessions()
    }

    /// Manually uploads a persisted local session to the currently configured APXY Core server.
    public static func shareLocalSession(id: String) async throws {
        guard let instance = activeInstance() else {
            throw ApxyLocalSessionShareError.sdkNotRunning
        }
        try await instance.shareLocalSession(id: id)
    }

    func capture(
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
    ) {
        guard let payload = CapturePayload.make(
            request: request,
            currentRequest: currentRequest,
            requestBody: requestBody,
            requestBodySource: requestBodySource,
            response: response,
            responseData: responseData,
            duration: duration,
            redirectCount: redirectCount,
            metrics: metrics,
            error: error
        ) else {
            return
        }

        let debugContext: DebugCaptureContext?
        if debugStore != nil {
            let errorInfo: ApxyDebugRecord.ErrorInfo?
            if let error {
                let nsError = error as NSError
                errorInfo = ApxyDebugRecord.ErrorInfo(
                    domain: nsError.domain,
                    code: nsError.code,
                    message: nsError.localizedDescription
                )
            } else {
                errorInfo = nil
            }
            debugContext = DebugCaptureContext(
                metrics: metrics.map(ApxyDebugRecord.Metrics.init),
                error: errorInfo
            )
        } else {
            debugContext = nil
        }

        let sessionManager = self.sessionManager
        Task {
            await sessionManager.capture(payload, debugContext: debugContext)
        }
    }

    private static func normalizeServerURL(_ value: String?) -> URL? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let parsed = URL(string: trimmed) else { return nil }
        guard let scheme = parsed.scheme?.lowercased(), ["http", "https", "ws", "wss"].contains(scheme) else {
            return nil
        }

        return parsed
    }

    private static func normalizeServerURL(_ value: URL?) -> URL? {
        guard let value else { return nil }
        return normalizeServerURL(value.absoluteString)
    }

    private static func normalizeFlushInterval(_ value: TimeInterval) -> TimeInterval {
        max(1, value)
    }

    private static func normalizeDomains(_ values: [String]?) -> [String]? {
        guard let values else { return nil }
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return normalized.isEmpty ? nil : normalized
    }

    private static func makeTransports(
        serverURL: URL?,
        transportMode: ApxyTransport,
        webSocketMaxReconnectAttempts: Int,
        webSocketReconnectCooldown: TimeInterval,
        connectionStateTracker: ConnectionStateTracker
    ) -> (SessionTransporting, RecordTransport, RecordDeliveryMode) {
        guard let serverURL else {
            return (LocalOnlySessionTransport(), LocalOnlyRecordTransport(), .buffered)
        }

        let sessionTransport = SessionTransport(serverURL: serverURL)

        let useWebSocket: Bool
        switch transportMode {
        case .webSocket:
            useWebSocket = true
        case .http:
            useWebSocket = false
        case .auto:
            if #available(iOS 13.0, macOS 10.15, *) {
                useWebSocket = true
            } else {
                useWebSocket = false
            }
        }

        if useWebSocket, #available(iOS 13.0, macOS 10.15, *) {
            return (
                sessionTransport,
                WebSocketTransport(
                    serverURL: serverURL,
                    connectionStateTracker: connectionStateTracker,
                    reconnectPolicy: WebSocketReconnectPolicy(
                        maxAttempts: webSocketMaxReconnectAttempts,
                        cooldown: webSocketReconnectCooldown
                    )
                ),
                .immediate
            )
        }

        return (
            sessionTransport,
            HTTPTransport(serverURL: serverURL, connectionStateTracker: connectionStateTracker),
            .buffered
        )
    }

    private func applyCapturedDomains(_ domains: [String]?) {
        if let domains, !domains.isEmpty {
            ApxyURLProtocol.domainFilter = DomainFilter(domains: domains)
        } else {
            ApxyURLProtocol.domainFilter = nil
        }
    }

    private func applyRuntimeConfiguration(_ configuration: ApxyRuntimeConfiguration) {
        let normalizedServerURL = Self.normalizeServerURL(configuration.serverURL)
        if configuration.serverURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
           normalizedServerURL == nil {
            SDKLogger.warn("ApxyCore: invalid serverURL '\(configuration.serverURL ?? "")' — using local-only mode")
        }

        let normalizedDomains = Self.normalizeDomains(configuration.capturedDomains)
        let normalizedFlushInterval = Self.normalizeFlushInterval(configuration.flushInterval)

        runtimeConfiguration = ApxyRuntimeConfiguration(
            serverURL: normalizedServerURL?.absoluteString,
            flushInterval: normalizedFlushInterval,
            capturedDomains: normalizedDomains
        )
        capturedDomains = normalizedDomains
        applyCapturedDomains(normalizedDomains)

        let (sessionTransport, recordTransport, deliveryMode) = Self.makeTransports(
            serverURL: normalizedServerURL,
            transportMode: transportMode,
            webSocketMaxReconnectAttempts: webSocketMaxReconnectAttempts,
            webSocketReconnectCooldown: webSocketReconnectCooldown,
            connectionStateTracker: connectionStateTracker
        )
        let sessionManager = self.sessionManager
        Task {
            await sessionManager.reconfigure(
                transport: sessionTransport,
                recordTransport: recordTransport,
                serverURL: normalizedServerURL?.absoluteString,
                recordDeliveryMode: deliveryMode,
                flushInterval: normalizedFlushInterval
            )
        }
    }

    private func shareLocalSession(id: String) async throws {
        guard let debugStore else {
            throw ApxyLocalSessionShareError.debugConsoleDisabled
        }
        guard let serverURLString = runtimeConfiguration.serverURL,
              let serverURL = Self.normalizeServerURL(serverURLString) else {
            throw ApxyLocalSessionShareError.missingServerURL
        }

        let payload = try await debugStore.loadSessionForSharing(id: id)
        let connectionTracker = ConnectionStateTracker { _ in }
        let sessionTransport = SessionTransport(serverURL: serverURL)
        let recordTransport = HTTPTransport(serverURL: serverURL, connectionStateTracker: connectionTracker)

        await debugStore.markSessionSyncState(
            id: id,
            state: .syncing,
            serverURL: serverURL.absoluteString,
            errorMessage: nil
        )

        do {
            let sdkClient = payload.session.sdkClient ?? ClientIdentity.build()
            try await sessionTransport.registerClient(sdkClient)
            try await sessionTransport.createSession(
                id: payload.session.id,
                name: payload.session.name,
                createdAt: payload.session.createdAt,
                clientID: sdkClient.id,
                context: payload.session.context ?? ClientContext()
            )

            for chunk in payload.records.chunked(maxRecords: 100, maxBytes: 512 * 1024) {
                try await recordTransport.send(records: chunk)
            }

            await debugStore.markSessionSyncState(
                id: id,
                state: .synced,
                serverURL: serverURL.absoluteString,
                errorMessage: nil
            )
        } catch {
            await debugStore.markSessionSyncState(
                id: id,
                state: .failed,
                serverURL: serverURL.absoluteString,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }

    static func activeInstance() -> Apxy? {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        return shared
    }

    private static func detachShared() -> Apxy? {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        let instance = shared
        shared = nil
        return instance
    }

    private func activate() {
        applyCapturedDomains(capturedDomains)
        ApxyURLProtocol.capturePolicy = capturePolicy

        connectionMonitor.start()
#if canImport(UIKit)
        lifecycleObserver.start()
#endif
        URLSessionSwizzler.install()
        let sessionManager = self.sessionManager
        startupTask = Task {
            await sessionManager.start()
        }
        SDKLogger.debug("traffic interception active")
    }

    private func shutdown() {
#if canImport(UIKit)
        lifecycleObserver.stop()
#endif
        URLSessionSwizzler.uninstall()
        ApxyURLProtocol.domainFilter = nil
        ApxyURLProtocol.capturePolicy = .performanceFirst
        connectionMonitor.stop()
        startupTask?.cancel()
        startupTask = nil

        let sessionManager = self.sessionManager
        let debugStore = self.debugStore
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await sessionManager.stop()
            if let debugStore {
                await debugStore.flush()
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}

private extension Array where Element == NetworkRecord {
    func chunked(maxRecords: Int, maxBytes: Int) -> [[NetworkRecord]] {
        guard !isEmpty else { return [] }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var chunks: [[NetworkRecord]] = []
        var currentChunk: [NetworkRecord] = []
        var currentBytes = 2

        for record in self {
            let recordBytes = (try? encoder.encode(record).count) ?? 0
            let separatorBytes = currentChunk.isEmpty ? 0 : 1
            let exceedsCount = currentChunk.count >= Swift.max(1, maxRecords)
            let exceedsBytes = !currentChunk.isEmpty && (currentBytes + separatorBytes + recordBytes) > Swift.max(1, maxBytes)

            if exceedsCount || exceedsBytes {
                chunks.append(currentChunk)
                currentChunk = []
                currentBytes = 2
            }

            currentChunk.append(record)
            currentBytes += recordBytes + (currentChunk.count > 1 ? 1 : 0)
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }
}

#if canImport(UIKit)
import UIKit

private final class AppLifecycleObserver {
    private let onBecomeActive: @Sendable () -> Void
    private let onEnterBackground: @Sendable () -> Void
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didEnterBackgroundObserver: NSObjectProtocol?

    init(
        onBecomeActive: @escaping @Sendable () -> Void,
        onEnterBackground: @escaping @Sendable () -> Void
    ) {
        self.onBecomeActive = onBecomeActive
        self.onEnterBackground = onEnterBackground
    }

    func start() {
        guard didBecomeActiveObserver == nil, didEnterBackgroundObserver == nil else { return }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [onBecomeActive] _ in
            onBecomeActive()
        }

        didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [onEnterBackground] _ in
            onEnterBackground()
        }
    }

    func stop() {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            self.didBecomeActiveObserver = nil
        }

        if let didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(didEnterBackgroundObserver)
            self.didEnterBackgroundObserver = nil
        }
    }

    deinit {
        stop()
    }
}
#endif

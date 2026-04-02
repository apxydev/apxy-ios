import Foundation

/// APXY iOS SDK — captures URLSession traffic and streams it to a local APXY instance.
///
/// ## Quick start (2 lines)
/// ```swift
/// import ApxySDK
/// Apxy.start(serverURL: "http://192.168.1.5:8080")
/// ```
///
/// ## Full config
/// ```swift
/// Apxy.start(
///     serverURL: "http://192.168.1.5:8080",
///     options: ApxyOptions(transport: .auto, bufferSize: 200)
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
    private let capturedDomains: [String]?
#if canImport(UIKit)
    private let lifecycleObserver: AppLifecycleObserver
#endif
    private var startupTask: Task<Void, Never>?

    private init(serverURL: URL, options: ApxyOptions) {
        let onEvent = options.onConnectionEvent
        let connectionStateTracker = ConnectionStateTracker { event in
            guard let onEvent else { return }
            Task { @MainActor in
                onEvent(event)
            }
        }

        let sessionTransport = SessionTransport(serverURL: serverURL)
        let recordTransport: any RecordTransport
        let deliveryMode: RecordDeliveryMode

        let useWebSocket: Bool
        switch options.transport {
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
            recordTransport = WebSocketTransport(
                serverURL: serverURL,
                connectionStateTracker: connectionStateTracker
            )
            deliveryMode = .immediate
        } else {
            recordTransport = HTTPTransport(
                serverURL: serverURL,
                connectionStateTracker: connectionStateTracker
            )
            deliveryMode = .buffered
        }

        self.sessionManager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            connectionStateTracker: connectionStateTracker,
            bufferCapacity: options.bufferSize,
            recordDeliveryMode: deliveryMode,
            flushInterval: options.flushInterval,
            sessionIdleTimeout: options.sessionIdleTimeout
        )
        self.connectionMonitor = ConnectionMonitor { [sessionManager] snapshot in
            Task {
                await sessionManager.updateConnection(snapshot)
            }
        }
        self.capturedDomains = options.capturedDomains
#if canImport(UIKit)
        self.lifecycleObserver = AppLifecycleObserver(
            onBecomeActive: { [sessionManager] in
                Task {
                    await sessionManager.appDidBecomeActive()
                }
            },
            onEnterBackground: { [sessionManager] in
                Task {
                    await sessionManager.appDidEnterBackground()
                }
            }
        )
#endif

        let transportLabel = (deliveryMode == .immediate) ? "webSocket" : "http"
        SDKLogger.debug(
            "started transport=\(transportLabel) bufferSize=\(options.bufferSize) flushInterval=\(options.flushInterval)"
        )
    }

    /// Start the SDK. Safe to call multiple times — subsequent calls are no-ops.
    public static func start(serverURL: String, options: ApxyOptions = .init()) {
#if !DEBUG
        guard options.enableInRelease else {
            SDKLogger.debug("ApxySDK: disabled in Release build (set enableInRelease: true to override)")
            return
        }
#endif

        guard let url = URL(string: serverURL) else {
            SDKLogger.warn("ApxySDK: invalid serverURL '\(serverURL)' — SDK not started")
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
            SDKLogger.warn("ApxySDK: unsupported context value for key '\(key)'")
#if DEBUG
            assertionFailure("Unsupported APXY context value for key '\(key)'")
#endif
            return
        }

        setContext(key: key, value: normalized)
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

        let sessionManager = self.sessionManager
        Task {
            await sessionManager.capture(payload)
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
        if let capturedDomains, !capturedDomains.isEmpty {
            ApxyURLProtocol.domainFilter = DomainFilter(domains: capturedDomains)
        } else {
            ApxyURLProtocol.domainFilter = nil
        }

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
        connectionMonitor.stop()
        startupTask?.cancel()
        startupTask = nil

        let sessionManager = self.sessionManager
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await sessionManager.stop()
            semaphore.signal()
        }
        semaphore.wait()
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

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
public final class Apxy: @unchecked Sendable {

    // MARK: Shared instance (nil = SDK inactive)

    /// The active SDK instance, or `nil` when the SDK is stopped / in Release build.
    static var shared: Apxy?

    // MARK: Dependencies

    private let buffer: RecordBuffer
    private let serverURL: URL
    private let sessionTransport: SessionTransport
    private let recordTransport: any RecordTransport
    private let sessionManager: SessionManager
    private let connectionMonitor: ConnectionMonitor
    /// When non-empty, only these host patterns are captured; `nil`/empty means all hosts.
    private let capturedDomains: [String]?
    private let captureMode: ApxyCaptureMode

    private let queue = DispatchQueue(label: "dev.apxy.sdk.capture", qos: .utility)

    // MARK: Init

    private init(serverURL: URL, options: ApxyOptions) {
        let buffer = RecordBuffer(capacity: options.bufferSize)
        let connectionMonitor = ConnectionMonitor()
        let sessionTransport = SessionTransport(serverURL: serverURL)
        let recordTransport: any RecordTransport

        let onEvent = options.onConnectionEvent
        let connectionStateTracker = ConnectionStateTracker { event in
            guard let onEvent else { return }
            DispatchQueue.main.async { onEvent(event) }
        }

        let useWS: Bool
        switch options.transport {
        case .webSocket: useWS = true
        case .http:      useWS = false
        case .auto:
            if #available(iOS 13.0, macOS 10.15, *) {
                useWS = true
            } else {
                useWS = false
            }
        }

        if useWS, #available(iOS 13.0, macOS 10.15, *) {
            recordTransport = WebSocketTransport(
                serverURL: serverURL,
                buffer: buffer,
                connectionStateTracker: connectionStateTracker
            )
        } else {
            recordTransport = HTTPTransport(
                serverURL: serverURL,
                buffer: buffer,
                flushInterval: options.flushInterval,
                connectionStateTracker: connectionStateTracker
            )
        }

        let transportLabel: String
        if useWS, #available(iOS 13.0, macOS 10.15, *) {
            transportLabel = "webSocket"
        } else {
            transportLabel = "http"
        }

        self.buffer = buffer
        self.serverURL = serverURL
        self.connectionMonitor = connectionMonitor
        self.capturedDomains = options.capturedDomains
        self.captureMode = options.captureMode
        self.sessionTransport = sessionTransport
        self.recordTransport = recordTransport
        self.sessionManager = SessionManager(
            transport: sessionTransport,
            buffer: buffer,
            connectionMonitor: connectionMonitor,
            connectionStateTracker: connectionStateTracker,
            sessionIdleTimeout: options.sessionIdleTimeout
        )

        SDKLogger.debug(
            "started transport=\(transportLabel) bufferSize=\(options.bufferSize) flushInterval=\(options.flushInterval)"
        )
    }

    // MARK: Public API

    /// Start the SDK. Safe to call multiple times — subsequent calls are no-ops.
    ///
    /// - Parameters:
    ///   - serverURL: Base URL of the running APXY Core instance, e.g. `"http://192.168.1.5:8080"`.
    ///   - options: Optional configuration. Defaults are suitable for most use-cases.
    public static func start(serverURL: String, options: ApxyOptions = .init()) {
#if !DEBUG
        guard options.enableInRelease else {
            SDKLogger.debug("ApxySDK: disabled in Release build (set enableInRelease: true to override)")
            return
        }
#endif
        guard shared == nil else { return }
        guard let url = URL(string: serverURL) else {
            SDKLogger.warn("ApxySDK: invalid serverURL '\(serverURL)' — SDK not started")
            return
        }

        SDKLogger.level = options.logLevel
        let instance = Apxy(serverURL: url, options: options)
        shared = instance
        instance.activate()
    }

    /// Stop the SDK, flush remaining records, and release all resources.
    public static func stop() {
        shared?.deactivate()
        SDKLogger.debug("stop: SDK stopped")
        shared = nil
    }

    /// Set the current authenticated user. Updates the session context immediately.
    public static func setUser(_ user: ApxyUser) {
        shared?.queue.async {
            shared?.sessionManager.context.setUser(user)
            shared?.sessionManager.updateContext()
        }
    }

    /// Attach a key-value tag to the current session.
    public static func setTag(key: String, value: String) {
        shared?.queue.async {
            shared?.sessionManager.context.setTag(key: key, value: value)
            shared?.sessionManager.updateContext()
        }
    }

    /// Attach arbitrary context to the current session under the given key.
    public static func setContext(key: String, value: Any) {
        shared?.queue.async {
            shared?.sessionManager.context.setContext(key: key, value: AnyCodable(value))
            shared?.sessionManager.updateContext()
        }
    }

    // MARK: Internal capture

    /// Called by the interceptors after each request/response cycle.
    func capture(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseData: Data?,
        duration: Int64,
        error: Error?
    ) {
        queue.async { [weak self] in
            self?.buildAndBuffer(
                request: request,
                response: response,
                responseData: responseData,
                duration: duration,
                error: error
            )
        }
    }

    // MARK: Private helpers

    private func activate() {
        if let domains = capturedDomains, !domains.isEmpty {
            ApxyURLProtocol.domainFilter = DomainFilter(domains: domains)
        } else {
            ApxyURLProtocol.domainFilter = nil
        }
        connectionMonitor.start()
        sessionManager.start()

        switch captureMode {
        case .sessionOnly:
            SDKLogger.debug("captureMode=sessionOnly: skipping traffic interception")

        case .alwaysCapture:
            recordTransport.start()
            URLSessionSwizzler.install()
            SDKLogger.debug("captureMode=alwaysCapture: traffic interception active")

        case .auto:
            // Query the server for proxy status. If the proxy is already running,
            // skip interception to avoid double-capturing every request.
            // Falls back to full interception if the check times out or fails.
            let url = serverURL
            ProxyDetector.checkProxyRunning(serverURL: url) { [weak self] proxyRunning in
                guard let self else { return }
                if proxyRunning {
                    SDKLogger.debug("captureMode=auto: proxy detected — skipping traffic interception (session-only)")
                } else {
                    self.recordTransport.start()
                    URLSessionSwizzler.install()
                    SDKLogger.debug("captureMode=auto: no proxy detected — traffic interception active")
                }
            }
        }
    }

    private func deactivate() {
        recordTransport.stop()
        connectionMonitor.stop()
        URLSessionSwizzler.uninstall()
        ApxyURLProtocol.domainFilter = nil
    }

    private func buildAndBuffer(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseData: Data?,
        duration: Int64,
        error: Error?
    ) {
        guard let urlString = request.url?.absoluteString,
              let host = request.url?.host else { return }

        let path = request.url?.path ?? "/"
        let tls = request.url?.scheme == "https"
        let statusCode = response?.statusCode ?? (error != nil ? -1 : 0)

        let reqHeaders = request.allHTTPHeaderFields.flatMap { dict -> [String: String]? in dict.isEmpty ? nil : dict }
        let resHeaders = response?.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }

        let record = NetworkRecord(
            id: UUID().uuidString,
            timestamp: Date(),
            method: request.httpMethod ?? "GET",
            url: urlString,
            host: host,
            path: path,
            requestHeaders: reqHeaders,
            requestBody: request.httpBody,
            requestContentType: request.value(forHTTPHeaderField: "Content-Type"),
            statusCode: statusCode,
            responseHeaders: resHeaders,
            responseBody: responseData,
            responseContentType: response?.value(forHTTPHeaderField: "Content-Type"),
            duration: duration,
            tls: tls,
            mocked: false,
            sessionID: sessionManager.currentSessionID
        )

        buffer.append(record)
        tryFlushImmediate(record)
    }

    private func tryFlushImmediate(_ record: NetworkRecord) {
        // For WebSocket transport, try to send immediately.
        // For HTTP batch transport, the timer will flush.
        recordTransport.send(records: [record]) { _ in }
    }
}

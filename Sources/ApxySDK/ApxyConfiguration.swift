import Foundation

/// Controls whether the SDK intercepts and captures URLSession traffic.
///
/// When both the APXY proxy and the SDK are active on the same device,
/// use `.auto` (the default) to avoid double-capturing every request.
public enum ApxyCaptureMode: Sendable {
    /// Automatically detect whether the APXY proxy is running.
    /// If the proxy is active, skip URLSession interception (the proxy already
    /// captures everything). If the proxy is inactive, activate interception.
    /// This is the recommended default for development builds.
    case auto
    /// Always intercept traffic regardless of proxy state.
    /// Use this only when you explicitly want SDK capture alongside the proxy
    /// (e.g. comparing SDK-specific session metadata with raw proxy records).
    case alwaysCapture
    /// Never intercept traffic. The SDK will still register the client and
    /// manage sessions, but no NetworkRecords will be sent from the SDK.
    /// Use this when the proxy is your sole capture mechanism.
    case sessionOnly
}

/// Transport strategy for sending captured records to APXY Core.
public enum ApxyTransport: Sendable {
    /// Batch POST every `flushInterval` seconds (default).
    case http
    /// Persistent WebSocket for real-time streaming.
    case webSocket
    /// Automatically choose WebSocket when available, fall back to HTTP.
    case auto
}

/// Log verbosity for SDK-internal messages.
public enum ApxyLogLevel: Int, Sendable {
    case none
    case warning
    case debug
}

/// Connection-related events for the APXY server URL and record transport.
///
/// Delivered on the **main queue** so it is safe to update UI from the handler.
public enum ApxyConnectionEvent: Sendable {
    /// Session or record transport could not reach `serverURL` (HTTP error, timeout, etc.).
    case serverUnavailable(reason: String)
    /// Session or transport succeeded after a prior `serverUnavailable`.
    case serverRecovered
    /// WebSocket to APXY Core was lost (reconnect is automatic).
    case transportDisconnected(reason: String?)
}

/// Full configuration for the ApxySDK.
public struct ApxyOptions: Sendable {
    /// Transport strategy. Default: `.auto`.
    public var transport: ApxyTransport
    /// Allow the SDK to run in non-DEBUG builds. Default: `false`.
    public var enableInRelease: Bool
    /// Ring buffer capacity for offline records. Default: `100`.
    public var bufferSize: Int
    /// Seconds between HTTP batch flushes. Default: `2.0`.
    public var flushInterval: TimeInterval
    /// SDK log verbosity. Default: `.warning`.
    public var logLevel: ApxyLogLevel
    /// Called on the main queue when the server endpoint or WebSocket transport state changes.
    public var onConnectionEvent: (@Sendable (ApxyConnectionEvent) -> Void)?
    /// When non-empty, only requests whose URL host matches an entry are captured.
    /// Use exact hosts (e.g. `api.example.com`) or `*.example.com` for any subdomain.
    /// `nil` or empty means capture all hosts (default).
    public var capturedDomains: [String]?
    /// How long the app can stay in the background before the next foreground
    /// transition starts a new session instead of resuming the current one.
    /// Default: 1800 seconds (30 minutes).
    public var sessionIdleTimeout: TimeInterval
    /// Controls whether the SDK intercepts URLSession traffic.
    /// Default: `.auto` — detects whether the APXY proxy is running and skips
    /// interception when it is, avoiding duplicate records.
    public var captureMode: ApxyCaptureMode

    public init(
        transport: ApxyTransport = .auto,
        enableInRelease: Bool = false,
        bufferSize: Int = 100,
        flushInterval: TimeInterval = 2.0,
        logLevel: ApxyLogLevel = .warning,
        onConnectionEvent: (@Sendable (ApxyConnectionEvent) -> Void)? = nil,
        capturedDomains: [String]? = nil,
        sessionIdleTimeout: TimeInterval = 1800,
        captureMode: ApxyCaptureMode = .auto
    ) {
        self.transport = transport
        self.enableInRelease = enableInRelease
        self.bufferSize = bufferSize
        self.flushInterval = flushInterval
        self.logLevel = logLevel
        self.onConnectionEvent = onConnectionEvent
        self.capturedDomains = capturedDomains
        self.sessionIdleTimeout = sessionIdleTimeout
        self.captureMode = captureMode
    }
}

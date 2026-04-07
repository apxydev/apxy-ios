import Foundation

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

/// Runtime-only configuration that can be applied after startup.
///
/// The values are session-scoped and not persisted automatically.
public struct ApxyRuntimeConfiguration: Sendable, Equatable {
    /// APXY server URL string. `nil` uses local-only mode.
    public var serverURL: String?
    /// Seconds between flushes for buffered HTTP mode.
    public var flushInterval: TimeInterval
    /// Optional list of allowed captured domains. `nil` captures all hosts.
    public var capturedDomains: [String]?

    public init(
        serverURL: String? = nil,
        flushInterval: TimeInterval = 2.0,
        capturedDomains: [String]? = nil
    ) {
        self.serverURL = serverURL
        self.flushInterval = flushInterval
        self.capturedDomains = capturedDomains
    }
}

/// Full configuration for ApxyCore.
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
    /// Maximum automatic WebSocket reconnect attempts before APXY pauses and lets
    /// the normal flush loop retry later. Default: `5`. Use `0` to disable
    /// automatic reconnects.
    public var webSocketMaxReconnectAttempts: Int
    /// Seconds APXY waits after exhausting automatic WebSocket reconnect attempts
    /// before allowing another reconnect burst. Default: `60`.
    public var webSocketReconnectCooldown: TimeInterval
    /// When non-empty, only requests whose URL host matches an entry are captured.
    /// Use exact hosts (e.g. `api.example.com`) or `*.example.com` for any subdomain.
    /// `nil` or empty means capture all hosts (default).
    public var capturedDomains: [String]?
    /// How long the app can stay in the background before the next foreground
    /// transition starts a new session instead of resuming the current one.
    /// Default: 1800 seconds (30 minutes).
    public var sessionIdleTimeout: TimeInterval
    /// In-memory debug console storage. Disabled by default.
    public var debugConsole: ApxyDebugOptions
    /// Bounds request/response payload capture work. Default: `.performanceFirst`.
    public var capturePolicy: ApxyCapturePolicy

    public init(
        transport: ApxyTransport = .auto,
        enableInRelease: Bool = false,
        bufferSize: Int = 100,
        flushInterval: TimeInterval = 2.0,
        logLevel: ApxyLogLevel = .warning,
        onConnectionEvent: (@Sendable (ApxyConnectionEvent) -> Void)? = nil,
        webSocketMaxReconnectAttempts: Int = 5,
        webSocketReconnectCooldown: TimeInterval = 60,
        capturedDomains: [String]? = nil,
        sessionIdleTimeout: TimeInterval = 1800,
        debugConsole: ApxyDebugOptions = .disabled,
        capturePolicy: ApxyCapturePolicy = .performanceFirst
    ) {
        self.transport = transport
        self.enableInRelease = enableInRelease
        self.bufferSize = bufferSize
        self.flushInterval = flushInterval
        self.logLevel = logLevel
        self.onConnectionEvent = onConnectionEvent
        self.webSocketMaxReconnectAttempts = max(0, webSocketMaxReconnectAttempts)
        self.webSocketReconnectCooldown = max(0, webSocketReconnectCooldown)
        self.capturedDomains = capturedDomains
        self.sessionIdleTimeout = sessionIdleTimeout
        self.debugConsole = debugConsole
        self.capturePolicy = capturePolicy
    }
}

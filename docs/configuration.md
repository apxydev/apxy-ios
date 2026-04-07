# Configuration

Full configuration reference for `Apxy iOS`.

## `Apxy.start`

```swift
import ApxyCore

Apxy.start()
```

Local-only mode captures traffic for in-app debugging. The convenience `Apxy.start()` also enables the local debug console by default.

To send traffic to desktop APXY, pass a server URL:

```swift
import ApxyCore

Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions()
)
```

You can also start in local-only mode with explicit options:

```swift
import ApxyCore

Apxy.start(
    options: ApxyOptions()
)
```

Note: `ApxyOptions.debugConsole` still defaults to `.disabled`. The auto-enabled debug console behavior is specific to the convenience `Apxy.start()` entry point.

## `ApxyOptions`

```swift
public struct ApxyOptions: Sendable {
    public var transport: ApxyTransport
    public var enableInRelease: Bool
    public var bufferSize: Int
    public var flushInterval: TimeInterval
    public var logLevel: ApxyLogLevel
    public var onConnectionEvent: (@Sendable (ApxyConnectionEvent) -> Void)?
    public var webSocketMaxReconnectAttempts: Int
    public var webSocketReconnectCooldown: TimeInterval
    public var capturedDomains: [String]?
    public var sessionIdleTimeout: TimeInterval
    public var debugConsole: ApxyDebugOptions
    public var capturePolicy: ApxyCapturePolicy
}
```

Default initializer:

```swift
ApxyOptions(
    transport: .auto,
    enableInRelease: false,
    bufferSize: 100,
    flushInterval: 2.0,
    logLevel: .warning,
    onConnectionEvent: nil,
    webSocketMaxReconnectAttempts: 5,
    webSocketReconnectCooldown: 60,
    capturedDomains: nil,
    sessionIdleTimeout: 1800,
    debugConsole: .disabled,
    capturePolicy: .performanceFirst
)
```

## `transport`

Controls how captured records are sent to APXY.

```swift
public enum ApxyTransport {
    case http
    case webSocket
    case auto
}
```

- `.http`: batch records and send on the flush loop
- `.webSocket`: push records immediately over WebSocket
- `.auto`: prefer WebSocket when available, otherwise fall back to HTTP

## `enableInRelease`

```swift
enableInRelease: Bool
```

- Default: `false`
- In non-DEBUG builds, the SDK does not start unless this is `true`

## `bufferSize`

```swift
bufferSize: Int
```

- Default: `100`
- Capacity of the in-memory record buffer used before records are flushed or retried

## `flushInterval`

```swift
flushInterval: TimeInterval
```

- Default: `2.0`
- Used by the buffered flush loop

## `logLevel`

```swift
public enum ApxyLogLevel: Int {
    case none
    case warning
    case debug
}
```

- Default: `.warning`

## `onConnectionEvent`

```swift
onConnectionEvent: (@Sendable (ApxyConnectionEvent) -> Void)?
```

Called on the main actor when APXY connectivity changes.

```swift
public enum ApxyConnectionEvent: Sendable {
    case serverUnavailable(reason: String)
    case serverRecovered
    case transportDisconnected(reason: String?)
}
```

Example:

```swift
Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        onConnectionEvent: { event in
            print("APXY event:", event)
        }
    )
)
```

## `webSocketMaxReconnectAttempts`

```swift
webSocketMaxReconnectAttempts: Int
```

- Default: `5`
- Set to `0` to disable automatic reconnect bursts

## `webSocketReconnectCooldown`

```swift
webSocketReconnectCooldown: TimeInterval
```

- Default: `60`
- Cooldown after reconnect attempts are exhausted

## `capturedDomains`

```swift
capturedDomains: [String]?
```

- Default: `nil`
- When `nil` or empty, capture all hosts
- Supports exact hosts and wildcard subdomains

Example:

```swift
ApxyOptions(
    capturedDomains: [
        "api.example.com",
        "*.analytics.io"
    ]
)
```

Rules:

- exact host: `api.example.com`
- wildcard subdomain: `*.example.com`
- bare domain and subdomains are distinct

## `sessionIdleTimeout`

```swift
sessionIdleTimeout: TimeInterval
```

- Default: `1800`
- If the app stays backgrounded longer than this, the next foreground starts a new session

## `debugConsole`

```swift
public struct ApxyDebugOptions: Sendable, Equatable {
    public var isEnabled: Bool
    public var memoryRecordLimit: Int
    public var persistedRecordLimit: Int
    public var storeURL: URL?
}
```

Default disabled value:

```swift
.disabled
```

Initializer:

```swift
ApxyDebugOptions(
    isEnabled: true,
    memoryRecordLimit: 200,
    persistedRecordLimit: 2_000,
    storeURL: nil
)
```

Meaning:

- `isEnabled`: turn on local debug recording
- `memoryRecordLimit`: records kept in memory for UI responsiveness
- `persistedRecordLimit`: records kept on disk across launches
- `storeURL`: custom store path if you do not want the default app-support location

## `capturePolicy`

```swift
public struct ApxyCapturePolicy: Sendable, Equatable {
    public var maxRequestBodyBytes: Int
    public var maxResponseBodyBytes: Int
    public var captureHTTPBodyStreams: Bool
    public var captureUploadFileBodies: Bool
}
```

Preset:

```swift
.performanceFirst
```

Initializer:

```swift
ApxyCapturePolicy(
    maxRequestBodyBytes: 64 * 1024,
    maxResponseBodyBytes: 64 * 1024,
    captureHTTPBodyStreams: false,
    captureUploadFileBodies: false
)
```

Use this to control how aggressively request and response bodies are sampled.

Example:

```swift
Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        capturePolicy: ApxyCapturePolicy(
            maxRequestBodyBytes: 32 * 1024,
            maxResponseBodyBytes: 128 * 1024,
            captureHTTPBodyStreams: true,
            captureUploadFileBodies: false
        )
    )
)
```

## User And Context APIs

After startup you can enrich the active session:

```swift
Apxy.setUser(ApxyUser(id: "user-123", email: "dev@example.com", name: "Dev User"))
Apxy.setTag(key: "env", value: "staging")
Apxy.setContext(key: "subscription", value: ["plan": "pro", "trial": false])
```

## Runtime Reconfiguration

You can update a running SDK instance without restarting the app:

```swift
Apxy.reconfigure(
    ApxyRuntimeConfiguration(
        serverURL: "http://192.168.1.5:8083",
        flushInterval: 5.0,
        capturedDomains: ["api.example.com", "*.example.com"]
    )
)
```

Read the active session-scoped values with:

```swift
let active = Apxy.activeRuntimeConfiguration
```

Notes:

- runtime changes are session-only and are not persisted across restart
- invalid `serverURL` input falls back to local-only mode immediately
- the embedded `ApxyUI` debug console exposes the same fields in its runtime settings screen

## Manual Session Sharing

Local debug persistence now keeps session metadata as well as records. That lets you manually share older on-device sessions after switching to a valid `serverURL`.

```swift
let sessions = await Apxy.shareableLocalSessions()
try await Apxy.shareLocalSession(id: sessions[0].id)
```

Notes:

- this is for persisted older sessions, not the currently active live-managed session
- manual sharing requires a valid active `serverURL`
- sharing retries are safe because APXY Core now treats the uploaded SDK session as an idempotent upsert

## Custom `URLSessionConfiguration`

If you use a custom session configuration and need explicit interception, insert `ApxyURLProtocol.self`.

```swift
import ApxyCore

let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [ApxyURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = URLSession(configuration: configuration)
```

## Example: Practical Setup

```swift
import ApxyCore

Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        transport: .auto,
        logLevel: .warning,
        capturedDomains: ["api.example.com"],
        debugConsole: .init(isEnabled: true),
        capturePolicy: .performanceFirst
    )
)
```

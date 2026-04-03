# Apxy iOS

Native iOS SDK for [APXY](https://apxy.dev).

`ApxyCore` captures `URLSession` traffic and streams it to APXY Core. `ApxyUI` adds an embedded SwiftUI console for local inspection inside your app, using the same capture pipeline rather than a second interceptor.

## Modules

| Module | Purpose | Platforms |
| --- | --- | --- |
| `ApxyCore` | Capture, session tracking, buffering, transport to APXY Core, local debug storage | iOS 14+, macOS 12+ |
| `ApxyUI` | Embedded SwiftUI request inspector backed by `ApxyCore` | iOS 16+, macOS 13+ |

## Features

- Capture `URLSession.shared`, default, and ephemeral traffic automatically
- Stream requests to APXY Core over HTTP or WebSocket
- Preserve session context such as user, tags, and custom metadata
- Filter capture by host
- Keep a local debug history on disk for in-app inspection
- Present an embedded SwiftUI network console with search, filters, detail view, and export

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/apxydev/apxy-ios", from: "0.1.0")
]
```

Add `ApxyCore` when you only need transport to APXY Core.

```swift
.product(name: "ApxyCore", package: "apxy-ios")
```

Add `ApxyUI` when you also want the embedded SwiftUI console.

```swift
.product(name: "ApxyUI", package: "apxy-ios")
```

## Quick Start

```swift
import ApxyCore

Apxy.start(serverURL: "http://192.168.1.5:8083")
```

Start as early as possible, ideally in `App.init` or `application(_:didFinishLaunchingWithOptions:)`, before building networking clients.

That is enough to capture traffic from:

- `URLSession.shared`
- default and ephemeral sessions created after `Apxy.start(...)`
- higher-level clients built on top of those sessions, including async/await flows

## Embedded Console

Enable local recording in `ApxyCore`, then present `ApxyUI` from your app.

```swift
import ApxyCore

Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        debugConsole: .init(
            isEnabled: true,
            memoryRecordLimit: 200,
            persistedRecordLimit: 2_000
        )
    )
)
```

```swift
import SwiftUI
import ApxyUI

struct DebugScreen: View {
    var body: some View {
        NavigationStack {
            ApxyDebugConsoleContainer()
        }
    }
}
```

If you need tighter control over presentation or dependency injection, resolve the active store from `ApxyCore` and pass it directly.

```swift
import ApxyCore
import ApxyUI

if let store = Apxy.activeDebugStore {
    ApxyDebugConsoleView(store: store)
}
```

`ApxyUI` does not install another network hook. It reads the same locally recorded requests already produced by `ApxyCore`.

## Full Configuration

```swift
import ApxyCore

Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        transport: .auto,
        enableInRelease: false,
        bufferSize: 100,
        flushInterval: 2.0,
        logLevel: .warning,
        capturedDomains: nil,
        sessionIdleTimeout: 1_800,
        debugConsole: .disabled
    )
)
```

## Domain Filtering

By default, `ApxyCore` captures every host reached through supported `URLSession` traffic. To limit capture:

```swift
Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        capturedDomains: ["api.myapp.com", "example.com", "*.analytics.io"]
    )
)
```

- `nil` or empty: capture all hosts
- exact host: `api.example.com`
- wildcard subdomain: `*.example.com`
- bare domain and subdomains are distinct, so list both when needed

## Custom URLSessionConfiguration

For custom configurations, add `ApxyURLProtocol.self` before constructing the session:

```swift
import ApxyCore

let configuration = URLSessionConfiguration.default
configuration.protocolClasses = [ApxyURLProtocol.self] + (configuration.protocolClasses ?? [])
let session = URLSession(configuration: configuration)
```

`ApxyCore` can only affect sessions created after startup.

## User Identity And Context

```swift
import ApxyCore

Apxy.setUser(ApxyUser(id: "user-123", email: "dev@example.com", name: "Dev User"))
Apxy.setTag(key: "env", value: "staging")
Apxy.setTag(key: "feature_flag", value: "new_checkout")
Apxy.setContext(key: "subscription", value: ["plan": "pro", "trial": false])
```

## Session Lifecycle

A session is created when the app becomes active. The `client_id` remains stable for the installed app, while `session_id` changes across launches and long background gaps.

```text
App launch / foreground  -> new session_id
setUser/setTag/setContext -> session patched in place
App background            -> session pauses
Foreground after timeout  -> new session_id
```

## Which Port?

APXY Core exposes the mobile SDK endpoint on the LAN-facing SDK server, typically `web port + 1`.

With the default APXY proxy setup:

- proxy: `8080`
- dashboard: `8082`
- SDK base URL: `http://<your-mac-lan-ip>:8083`

After `apxy proxy start`, use the SDK URL printed by APXY startup logs.

## Troubleshooting

### "The Internet connection appears to be offline"

For a LAN URL such as `http://192.168.x.x:8083`, this usually means iOS blocked or could not route to the local host.

1. Add `NSLocalNetworkUsageDescription` to `Info.plist`.
2. If you use `http://`, allow local networking in ATS, for example with `NSAppTransportSecurity` and `NSAllowsLocalNetworking = YES`.
3. Make sure the device and Mac are on the same network.
4. Verify the APXY SDK endpoint is reachable from another machine on the same LAN.

### No requests in the console

1. Call `Apxy.start(...)` before creating networking clients.
2. Enable `debugConsole` in `ApxyOptions`.
3. For custom session configurations, insert `ApxyURLProtocol.self`.
4. If you present `ApxyDebugConsoleContainer()`, make sure you are on iOS 16+ or macOS 13+.

## Architecture

```text
URLSession shared/default/ephemeral
    -> capture
    -> local debug store
    -> HTTPTransport or WebSocketTransport
    -> APXY Core

ApxyUI
    -> reads snapshots from the local debug store
    -> renders list, filters, details, and export
```

## License

MIT

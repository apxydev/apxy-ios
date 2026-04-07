# Apxy iOS

`Apxy iOS` captures `URLSession` traffic from your app. You can inspect requests directly inside the app with `ApxyUI`, or send captured sessions and traffic logs to [APXY](https://github.com/apxydev/apxy) for inspection in the Web UI and CLI.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/apxydev/apxy-ios", from: "0.1.0")
]
```

Add `ApxyCore` if you only need request capture and transport:

```swift
.product(name: "ApxyCore", package: "apxy-ios")
```

Add `ApxyUI` if you also want the embedded debug console:

```swift
.product(name: "ApxyUI", package: "apxy-ios")
```

## Getting Started

Start Apxy as early as possible, ideally in `App.init` or app launch.

```swift
import ApxyCore

Apxy.start()
```

That is enough to capture traffic from:

- `URLSession.shared`
- default and ephemeral sessions created after startup
- libraries built on top of `URLSession`

`Apxy.start()` also enables the local debug console by default, so you can present `ApxyUI` to inspect request and response data inside the app.

## Use With APXY Server

If you want to send captured sessions and traffic logs to APXY Server, start Apxy with a server URL that points to APXY:

```swift
import ApxyCore

Apxy.start(serverURL: "http://<your-mac-lan-ip>:8083")
```

Remote capture now defaults to buffered HTTP delivery for lower app overhead. If you explicitly want near-realtime streaming, pass `ApxyOptions(transport: .webSocket)`.

APXY is a local HTTP/HTTPS debugging proxy and traffic inspection tool for developers and AI coding agents. It lets you capture, inspect, mock, replay, and diff traffic from a CLI and Web UI.

- GitHub: https://github.com/apxydev/apxy
- Website: https://apxy.dev

## APXY Pro

APXY has a free tier for first capture, but the full remote workflow is aimed at APXY Pro.

If you want to keep sending SDK sessions and traffic logs without free-tier limits, use APXY Pro. It unlocks unlimited traffic history together with the full replay, diff, and advanced debugging workflow in APXY.

## Embedded Debug Console

```swift
import SwiftUI
import ApxyUI

struct DebugScreen: View {
    var body: some View {
        ApxyDebugConsoleContainer()
    }
}
```

If you want full manual control, you can still configure `debugConsole` explicitly through `ApxyOptions`.

When using a remote `serverURL`, keep `debugConsole` disabled unless you actively need the embedded console. Running both together increases capture and persistence overhead.

The embedded console also includes a runtime settings screen for temporary debug-session changes like `serverURL`, `flushInterval`, and `capturedDomains`.

### Screenshots

| Sessions | Request Details |
| --- | --- |
| ![Apxy embedded debug console showing captured sessions](assets/apxy-sessions.png) | ![Apxy embedded debug console showing request details](assets/apxy-request-details.png) |

| Live Traffic | Runtime Settings |
| --- | --- |
| ![Apxy embedded debug console showing live traffic](assets/apxy-live-traffic.png) | ![Apxy embedded debug console showing runtime settings](assets/apxy-settings.png) |

## Documentation

- Full configuration: [docs/configuration.md](docs/configuration.md)

## Requirements

| Module | Platforms |
| --- | --- |
| `ApxyCore` | iOS 15+, macOS 12+ |
| `ApxyUI` | iOS 16+, macOS 13+ |

## License

MIT

# Apxy iOS

`Apxy iOS` captures `URLSession` traffic from your app. You can inspect requests directly inside the app with `ApxyUI`, or send them to [APXY](https://github.com/apxydev/apxy) on desktop.

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

## Use With APXY Proxy

If you want to inspect request and response traffic from desktop, start Apxy with a server URL that points to APXY:

```swift
import ApxyCore

Apxy.start(serverURL: "http://<your-mac-lan-ip>:8083")
```

APXY is a local HTTP/HTTPS debugging proxy and traffic inspection tool for developers and AI coding agents. It lets you capture, inspect, mock, replay, and diff traffic from a CLI and Web UI.

- GitHub: https://github.com/apxydev/apxy
- Website: https://apxy.dev

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

The embedded console also includes a runtime settings screen for temporary debug-session changes like `serverURL`, `flushInterval`, and `capturedDomains`.

## Documentation

- Full configuration: [docs/configuration.md](docs/configuration.md)

## Requirements

| Module | Platforms |
| --- | --- |
| `ApxyCore` | iOS 15+, macOS 12+ |
| `ApxyUI` | iOS 16+, macOS 13+ |

## License

MIT

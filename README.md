# ApxySDK for iOS

Native iOS SDK for [APXY](https://apxy.dev) — intercepts URLSession traffic and streams it directly to your local APXY instance for debugging and mocking.

## Requirements

- iOS 14+ / macOS 12+
- Swift 5.9+
- APXY Core running locally

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/apxydev/apxy-ios", from: "0.1.0")
]
```

## Quick Start

```swift
import ApxySDK

// In AppDelegate.application(_:didFinishLaunchingWithOptions:) or App.init
// Use the LAN-facing SDK base URL from APXY startup (see below), NOT the proxy port.
Apxy.start(serverURL: "http://192.168.1.5:8083")
```

That's it — all URLSession traffic (including Alamofire, URLSession async/await) is now automatically captured.

### Which port?

APXY Core exposes the SDK HTTP API on the **mobile / LAN server** (default **web port + 1**). With default proxy port **8080**, the dashboard is **8082** and the SDK base URL is **`http://<your-mac-LAN-ip>:8083`**. After `apxy proxy start`, check stderr for a line like `SDK (iOS): http://192.168.x.x:8083` and use that as `serverURL`. If you bind the dashboard to `0.0.0.0` instead of localhost, the mobile server may not start; use the dashboard port from the startup log in that case.

## User Identity

```swift
// After the user logs in
Apxy.setUser(ApxyUser(id: "user-123", email: "dev@example.com", name: "Dev User"))

// Attach tags to the session
Apxy.setTag(key: "env", value: "staging")
Apxy.setTag(key: "feature_flag", value: "new_checkout")

// Attach arbitrary context
Apxy.setContext(key: "subscription", value: ["plan": "pro", "trial": false])
```

## Full Configuration

```swift
Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        transport: .auto,          // .http | .webSocket | .auto
        enableInRelease: false,    // true to allow non-DEBUG builds
        bufferSize: 100,           // ring buffer capacity when offline
        flushInterval: 2.0,        // HTTP batch flush interval in seconds
        logLevel: .warning,        // .none | .warning | .debug
        capturedDomains: nil       // optional host allowlist (see Domain filtering)
    )
)
```

## Domain filtering

By default the SDK captures **all** URLSession hosts. To limit capture to specific hosts, pass a non-empty `capturedDomains` array:

```swift
Apxy.start(
    serverURL: "http://192.168.1.5:8083",
    options: ApxyOptions(
        capturedDomains: ["api.myapp.com", "*.analytics.io"]
    )
)
```

- **`nil` or empty** — same as default: capture every host.
- **Exact host** — e.g. `api.example.com` matches only that host (comparison is case-insensitive).
- **Wildcard** — `*.example.com` matches any subdomain such as `api.example.com` or `v2.api.example.com`, but **not** the bare domain `example.com` (list `example.com` separately if you need it).

## Session Lifecycle

A new session is created every time the app becomes active (launch or foreground from background). Session context (user, tags, custom context) is preserved across foreground cycles until you explicitly clear it.

```
App launch / foreground  → new session_id created
setUser/setTag/setContext → session patched in-place
App background / killed  → session ends
App foreground again     → new session_id (same client_id)
```

## Troubleshooting: “The Internet connection appears to be offline”

That message comes from **URLSession** (often error code **-1009**). For a **LAN** URL like `http://192.168.x.x:8083`, it usually does **not** mean Wi‑Fi is off; iOS is blocking or has no route to that host.

1. **Local Network permission (iOS 14+)**  
   Add `NSLocalNetworkUsageDescription` to your app’s **Info.plist** with a short reason (e.g. “Connect to APXY on your machine for debugging”). The first time the app talks to a private IP, the user may need to allow **Local Network** in **Settings → Your App**.

2. **Same network**  
   The phone/simulator must reach `192.168.50.44` (same Wi‑Fi as the machine running APXY, or correct routing). **Cellular-only** cannot reach a home LAN IP.

3. **HTTP (cleartext) to a local IP**  
   If you use `http://` (not `https://`), ensure **App Transport Security** allows local networking, e.g. `NSAppTransportSecurity` → `NSAllowsLocalNetworking` = `YES`. Without it, ATS may reject the connection.

4. **Server actually listening**  
   From a Mac on the same LAN, hit the SDK base URL (see **Which port?** above), e.g. `curl -sS -o /dev/null -w "%{http_code}" -X POST http://192.168.50.44:8083/api/v1/sdk/sessions -H 'Content-Type: application/json' -d '{}'`. You should get a non-connection error (e.g. 400) if the route exists. If connection fails, fix the host/firewall/APXY process or use the port printed at startup.

The SDK only uses `URLSession` to your `serverURL`; it cannot grant Local Network or ATS permissions for the host app.

## Graceful Fallback

- **Release builds**: Complete no-op unless `enableInRelease: true`
- **No server URL**: SDK inactive, zero overhead
- **Server unreachable**: Ring buffer holds up to `bufferSize` records; oldest dropped when full; auto-flush on reconnect
- **Never blocks**: All capture and transmission happens asynchronously
- **Never crashes**: All SDK code runs inside do/catch; errors logged to console only

## Data Model

```
sdk_clients          — stable device+app identity (one row per device/app combo)
    ↓ sdk_client_id
traffic_sessions     — per app-foreground lifecycle, links to sdk_client
    ↓ session_id
traffic_logs         — individual captured requests (unchanged)
```

## Architecture

```
URLSession (swizzled)
    ↓ capture()
RecordBuffer (ring, in-memory)
    ↓ flush (timer / ws send)
HTTPTransport   or   WebSocketTransport
    ↓
APXY Core /api/v1/sdk/traffic (on the mobile/LAN port from startup)
```

## License

MIT

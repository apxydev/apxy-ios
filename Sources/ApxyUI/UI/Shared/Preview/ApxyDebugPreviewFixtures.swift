import SwiftUI
import ApxyCore

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
enum ApxyDebugPreviewFixtures {
    static let storeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("apxy-preview-export.json")

    static let successRecord = makeRecord(
        id: "req-success",
        capturedAt: previewNow.addingTimeInterval(-180),
        sessionID: "session-alpha",
        method: "GET",
        host: "api.apxy.dev",
        path: "/v1/messages",
        statusCode: 200,
        responseBody: Data(
            """
            {
              "items": [
                { "id": "msg_1", "title": "Preview payload" },
                { "id": "msg_2", "title": "Readable in Xcode" }
              ]
            }
            """.utf8
        )
    )

    static let archiveListRecord = makeRecord(
        id: "req-archive-list",
        capturedAt: previewNow.addingTimeInterval(-330),
        sessionID: "session-omega",
        method: "GET",
        host: "archive.apxy.dev",
        path: "/v1/snapshots",
        statusCode: 200,
        duration: 0.31,
        responseBody: Data(
            """
            {
              "snapshots": [
                { "id": "snap_001", "size": 2048 },
                { "id": "snap_002", "size": 1024 }
              ]
            }
            """.utf8
        )
    )

    static let archiveRestoreRecord = makeRecord(
        id: "req-archive-restore",
        capturedAt: previewNow.addingTimeInterval(-300),
        sessionID: "session-omega",
        method: "POST",
        host: "archive.apxy.dev",
        path: "/v1/snapshots/snap_001/restore",
        statusCode: 409,
        duration: 0.67,
        requestBody: Data(
            """
            {
              "target": "staging"
            }
            """.utf8
        ),
        responseBody: Data(
            """
            {
              "error": "conflict",
              "message": "Snapshot is already mounted"
            }
            """.utf8
        ),
        error: .init(domain: "Preview", code: 409, message: "Snapshot already mounted")
    )

    static let redirectedRecord = makeRecord(
        id: "req-redirect",
        capturedAt: previewNow.addingTimeInterval(-120),
        sessionID: "session-alpha",
        method: "POST",
        host: "api.apxy.dev",
        path: "/v1/login",
        currentURL: "https://auth.apxy.dev/oauth/token",
        currentHost: "auth.apxy.dev",
        currentPath: "/oauth/token",
        statusCode: 201,
        redirectCount: 1,
        duration: 0.91,
        requestBody: Data(
            """
            {
              "email": "preview@apxy.dev",
              "password": "••••••••"
            }
            """.utf8
        ),
        responseBody: Data(
            """
            {
              "accessToken": "preview-token",
              "expiresIn": 3600
            }
            """.utf8
        )
    )

    static let failedRecord = makeRecord(
        id: "req-failure",
        capturedAt: previewNow.addingTimeInterval(-60),
        sessionID: "session-beta",
        method: "PATCH",
        host: "edge.apxy.dev",
        path: "/v1/profile",
        statusCode: 503,
        duration: 1.42,
        responseBody: Data(
            """
            {
              "error": "service_unavailable",
              "message": "Upstream origin timed out"
            }
            """.utf8
        ),
        error: .init(domain: "Preview", code: 503, message: "Service unavailable"),
        metrics: makeMetrics(duration: 1.42, statusCode: 503)
    )

    static let mockedRecord = makeRecord(
        id: "req-mock",
        capturedAt: previewNow,
        sessionID: "session-beta",
        method: "DELETE",
        host: "mock.apxy.dev",
        path: "/v1/cached-item",
        statusCode: 204,
        duration: 0.08,
        responseBody: Data(),
        isMocked: true
    )

    static let uploadRecord = makeRecord(
        id: "req-upload",
        capturedAt: previewNow.addingTimeInterval(-30),
        sessionID: "session-gamma",
        method: "PUT",
        host: "uploads.apxy.dev",
        path: "/v1/assets/avatar",
        statusCode: 202,
        duration: 2.36,
        requestHeaders: [
            "Accept": "application/json",
            "Content-Encoding": "gzip",
            "X-Preview": "true",
        ],
        requestBody: Data(repeating: 0x41, count: 32_768),
        requestContentType: "image/jpeg",
        responseBody: Data(
            """
            {
              "jobId": "job_preview_123",
              "state": "queued"
            }
            """.utf8
        ),
        responseHeaders: [
            "Content-Type": "application/json",
            "Retry-After": "3",
            "X-Request-ID": "req-upload",
        ]
    )

    static let unauthorizedRecord = makeRecord(
        id: "req-unauthorized",
        capturedAt: previewNow.addingTimeInterval(-15),
        sessionID: "session-beta",
        method: "POST",
        host: "billing.apxy.dev",
        path: "/v1/payment-intents",
        statusCode: 401,
        duration: 0.44,
        requestBody: Data(
            """
            {
              "amount": 4200,
              "currency": "usd"
            }
            """.utf8
        ),
        responseBody: Data(
            """
            {
              "error": "unauthorized",
              "message": "API key is missing or invalid"
            }
            """.utf8
        ),
        error: .init(domain: "Preview", code: 401, message: "Unauthorized")
    )

    static let htmlRecord = makeRecord(
        id: "req-status-page",
        capturedAt: previewNow.addingTimeInterval(-5),
        sessionID: "session-gamma",
        method: "GET",
        host: "status.apxy.dev",
        path: "/incidents/latest",
        statusCode: 200,
        duration: 0.19,
        responseBody: Data(
            """
            <html>
              <body>
                <h1>All systems operational</h1>
                <p>No active incidents.</p>
              </body>
            </html>
            """.utf8
        ),
        responseHeaders: [
            "Cache-Control": "max-age=60",
            "Content-Type": "text/html; charset=utf-8",
            "X-Request-ID": "req-status-page",
        ],
        responseContentType: "text/html; charset=utf-8"
    )

    static let syncRecord = makeRecord(
        id: "req-sync",
        capturedAt: previewNow.addingTimeInterval(-12),
        sessionID: "session-delta",
        method: "GET",
        host: "sync.apxy.dev",
        path: "/v1/state",
        statusCode: 200,
        duration: 0.11,
        responseBody: Data(
            """
            {
              "cursor": "cur_842",
              "pendingChanges": 3
            }
            """.utf8
        )
    )

    static let checkoutRecord = makeRecord(
        id: "req-checkout",
        capturedAt: previewNow.addingTimeInterval(-9),
        sessionID: "session-delta",
        method: "POST",
        host: "checkout.apxy.dev",
        path: "/v1/orders",
        statusCode: 202,
        duration: 0.58,
        requestBody: Data(
            """
            {
              "cartId": "cart_preview",
              "paymentMethod": "card"
            }
            """.utf8
        ),
        responseBody: Data(
            """
            {
              "orderId": "ord_preview_42",
              "state": "processing"
            }
            """.utf8
        )
    )

    static let rateLimitedRecord = makeRecord(
        id: "req-rate-limit",
        capturedAt: previewNow.addingTimeInterval(-6),
        sessionID: "session-delta",
        method: "GET",
        host: "search.apxy.dev",
        path: "/v1/query?q=swiftui",
        statusCode: 429,
        duration: 0.23,
        responseBody: Data(
            """
            {
              "error": "rate_limited",
              "retryAfter": 5
            }
            """.utf8
        ),
        responseHeaders: [
            "Content-Type": "application/json",
            "Retry-After": "5",
            "X-Request-ID": "req-rate-limit",
        ],
        error: .init(domain: "Preview", code: 429, message: "Too many requests")
    )

    static let mockedProfileRecord = makeRecord(
        id: "req-profile-mock",
        capturedAt: previewNow.addingTimeInterval(-2),
        sessionID: "session-delta",
        method: "GET",
        host: "profile.apxy.dev",
        path: "/v1/me",
        statusCode: 200,
        duration: 0.03,
        responseBody: Data(
            """
            {
              "id": "usr_preview",
              "tier": "pro"
            }
            """.utf8
        ),
        isMocked: true
    )

    static let records = [
        mockedProfileRecord,
        rateLimitedRecord,
        checkoutRecord,
        htmlRecord,
        unauthorizedRecord,
        syncRecord,
        mockedRecord,
        uploadRecord,
        failedRecord,
        redirectedRecord,
        successRecord,
        archiveRestoreRecord,
        archiveListRecord,
    ]

    static let sessions = [
        ApxyDebugSession(
            id: "session-omega",
            startedAt: previewNow.addingTimeInterval(-360),
            lastEventAt: previewNow.addingTimeInterval(-300),
            requestCount: 2,
            failureCount: 1,
            syncState: .synced
        ),
        ApxyDebugSession(
            id: "session-alpha",
            startedAt: previewNow.addingTimeInterval(-240),
            lastEventAt: previewNow.addingTimeInterval(-120),
            requestCount: 2,
            failureCount: 0,
            syncState: .failed
        ),
        ApxyDebugSession(
            id: "session-beta",
            startedAt: previewNow.addingTimeInterval(-90),
            lastEventAt: previewNow,
            requestCount: 3,
            failureCount: 2,
            syncState: .syncing
        ),
        ApxyDebugSession(
            id: "session-gamma",
            startedAt: previewNow.addingTimeInterval(-45),
            lastEventAt: previewNow.addingTimeInterval(-5),
            requestCount: 2,
            failureCount: 0,
            syncState: .localOnly
        ),
        ApxyDebugSession(
            id: "session-delta",
            startedAt: previewNow.addingTimeInterval(-14),
            lastEventAt: previewNow.addingTimeInterval(-2),
            requestCount: 4,
            failureCount: 1,
            syncState: .liveManaged
        ),
    ]

    static let activeFilters = ["Errors", "session-beta", "PATCH"]

    static func makeStore() -> ApxyDebugStore {
        ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 20,
                persistedRecordLimit: 20,
                storeURL: storeURL
            )
        )
    }

    static func populate(_ store: ApxyDebugStore) async {
        await store.clear()
        for record in records.reversed() {
            await store.append(record)
        }
    }

    private static let previewNow = Date(timeIntervalSince1970: 1_744_000_000)

    private static func makeRecord(
        id: String,
        capturedAt: Date,
        sessionID: String,
        method: String,
        host: String,
        path: String,
        currentURL: String? = nil,
        currentHost: String? = nil,
        currentPath: String? = nil,
        statusCode: Int,
        redirectCount: Int = 0,
        duration: TimeInterval = 0.24,
        requestHeaders: [String: String] = [
            "Accept": "application/json",
            "X-Preview": "true",
        ],
        requestBody: Data? = nil,
        requestContentType: String? = "application/json",
        responseBody: Data?,
        responseHeaders: [String: String]? = nil,
        responseContentType: String? = "application/json",
        error: ApxyDebugRecord.ErrorInfo? = nil,
        metrics: ApxyDebugRecord.Metrics? = nil,
        isMocked: Bool = false
    ) -> ApxyDebugRecord {
        let url = "https://\(host)\(path)"
        let currentHeaders = currentURL == nil ? [:] : ["X-Redirected-By": "Preview Gateway"]
        let resolvedResponseHeaders = responseHeaders ?? [
            "Content-Type": responseContentType ?? "application/octet-stream",
            "X-Request-ID": id,
        ]

        return ApxyDebugRecord(
            id: id,
            capturedAt: capturedAt,
            sessionID: sessionID,
            request: .init(
                method: method,
                url: url,
                host: host,
                path: path,
                headers: requestHeaders,
                body: requestBody,
                bodySize: requestBody.map { Int64($0.count) },
                contentType: requestBody == nil ? nil : requestContentType,
                currentURL: currentURL,
                currentHost: currentHost,
                currentPath: currentPath,
                currentHeaders: currentHeaders
            ),
            response: .init(
                statusCode: statusCode,
                headers: resolvedResponseHeaders,
                body: responseBody,
                bodySize: responseBody.map { Int64($0.count) },
                contentType: responseContentType
            ),
            transfer: .init(
                requestHeaderBytesSent: 142,
                requestBodyBytesBeforeEncoding: requestBody.map { Int64($0.count) },
                requestBodyBytesSent: requestBody.map { Int64($0.count) },
                responseHeaderBytesReceived: 118,
                responseBodyBytesReceived: responseBody.map { Int64($0.count) },
                responseBodyBytesAfterDecoding: responseBody.map { Int64($0.count) }
            ),
            metrics: metrics,
            error: error,
            redirectCount: redirectCount,
            duration: duration,
            isTLS: true,
            isMocked: isMocked
        )
    }

    private static func makeMetrics(
        duration: TimeInterval,
        statusCode: Int
    ) -> ApxyDebugRecord.Metrics {
        let start = previewNow.addingTimeInterval(-60)
        let end = start.addingTimeInterval(duration)

        return .init(
            taskInterval: DateInterval(start: start, end: end),
            redirectCount: 0,
            transactions: [
                .init(
                    fetchType: "networkLoad",
                    requestURL: "https://edge.apxy.dev/v1/profile",
                    responseStatusCode: statusCode,
                    networkProtocolName: "h2",
                    localAddress: "192.168.1.24",
                    remoteAddress: "34.120.8.10",
                    localPort: 54321,
                    remotePort: 443,
                    reusedConnection: false,
                    proxyConnection: false,
                    resourceFetchStart: start,
                    domainLookupStart: start,
                    domainLookupEnd: start.addingTimeInterval(0.03),
                    connectStart: start.addingTimeInterval(0.03),
                    secureConnectionStart: start.addingTimeInterval(0.06),
                    secureConnectionEnd: start.addingTimeInterval(0.12),
                    connectEnd: start.addingTimeInterval(0.16),
                    requestStart: start.addingTimeInterval(0.18),
                    requestEnd: start.addingTimeInterval(0.24),
                    responseStart: start.addingTimeInterval(0.82),
                    responseEnd: end,
                    transfer: .init(
                        requestHeaderBytesSent: 142,
                        requestBodyBytesBeforeEncoding: 61,
                        requestBodyBytesSent: 61,
                        responseHeaderBytesReceived: 118,
                        responseBodyBytesReceived: 78,
                        responseBodyBytesAfterDecoding: 78
                    )
                ),
            ]
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
private final class ApxyDebugPreviewStoreHolder: ObservableObject {
    let store = ApxyDebugPreviewFixtures.makeStore()
    var didLoad = false
}

@available(iOS 17.0, macOS 14.0, *)
struct ApxyDebugPreviewStoreContainer<Content: View>: View {
    @StateObject private var holder = ApxyDebugPreviewStoreHolder()
    private let content: (ApxyDebugStore) -> Content

    init(@ViewBuilder content: @escaping (ApxyDebugStore) -> Content) {
        self.content = content
    }

    var body: some View {
        content(holder.store)
            .task {
                guard !holder.didLoad else { return }
                holder.didLoad = true
                await ApxyDebugPreviewFixtures.populate(holder.store)
            }
    }
}
#endif

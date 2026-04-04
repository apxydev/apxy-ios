import SwiftUI
import ApxyCore

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
enum ApxyDebugPreviewFixtures {
    static let exportURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
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

    static let records = [mockedRecord, failedRecord, redirectedRecord, successRecord]

    static let sessions = [
        ApxyDebugSession(
            id: "session-alpha",
            startedAt: previewNow.addingTimeInterval(-240),
            lastEventAt: previewNow.addingTimeInterval(-120),
            requestCount: 2,
            failureCount: 0
        ),
        ApxyDebugSession(
            id: "session-beta",
            startedAt: previewNow.addingTimeInterval(-90),
            lastEventAt: previewNow,
            requestCount: 2,
            failureCount: 1
        ),
    ]

    static let activeFilters = ["Errors", "session-beta", "PATCH"]

    static func makeStore() -> ApxyDebugStore {
        ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 20,
                persistedRecordLimit: 20,
                storeURL: exportURL
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
        requestBody: Data? = nil,
        responseBody: Data?,
        error: ApxyDebugRecord.ErrorInfo? = nil,
        metrics: ApxyDebugRecord.Metrics? = nil,
        isMocked: Bool = false
    ) -> ApxyDebugRecord {
        let url = "https://\(host)\(path)"
        let currentHeaders = currentURL == nil ? [:] : ["X-Redirected-By": "Preview Gateway"]

        return ApxyDebugRecord(
            id: id,
            capturedAt: capturedAt,
            sessionID: sessionID,
            request: .init(
                method: method,
                url: url,
                host: host,
                path: path,
                headers: [
                    "Accept": "application/json",
                    "X-Preview": "true",
                ],
                body: requestBody,
                bodySize: requestBody.map { Int64($0.count) },
                contentType: requestBody == nil ? nil : "application/json",
                currentURL: currentURL,
                currentHost: currentHost,
                currentPath: currentPath,
                currentHeaders: currentHeaders
            ),
            response: .init(
                statusCode: statusCode,
                headers: [
                    "Content-Type": "application/json",
                    "X-Request-ID": id,
                ],
                body: responseBody,
                bodySize: responseBody.map { Int64($0.count) },
                contentType: "application/json"
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

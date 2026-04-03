import Foundation
import Testing
@testable import ApxyCore

struct ApxyDebugStoreTests {
    @Test func appendPersistsAndRestoresRecords() async throws {
        let fileURL = makeStoreURL()
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: fileURL
            )
        )

        await store.append(makeRecord(id: "one", sessionID: "session-a"))
        await store.flush()

        let restoredStore = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: fileURL
            )
        )
        let snapshot = await restoredStore.snapshot()

        #expect(snapshot.records.count == 1)
        #expect(snapshot.records.first?.id == "one")
    }

    @Test func persistedLimitPrunesOlderRecords() async {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 2,
                storeURL: makeStoreURL()
            )
        )

        await store.append(makeRecord(id: "one", sessionID: "session-a"))
        await store.append(makeRecord(id: "two", sessionID: "session-a"))
        await store.append(makeRecord(id: "three", sessionID: "session-b"))

        let snapshot = await store.snapshot()
        #expect(snapshot.records.map(\.id) == ["three", "two"])
    }

    @Test func appendCoalescesDiskWritesUntilFlush() async {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )

        await store.append(makeRecord(id: "one", sessionID: "session-a"))
        await store.append(makeRecord(id: "two", sessionID: "session-a"))
        await store.append(makeRecord(id: "three", sessionID: "session-b"))

        #expect(await store.persistWriteCountForTesting == 0)

        await store.flush()

        #expect(await store.persistWriteCountForTesting == 1)
    }

    @Test func snapshotBuildsSessionSummaries() async {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )

        await store.append(makeRecord(id: "one", sessionID: "session-a", statusCode: 200))
        await store.append(makeRecord(id: "two", sessionID: "session-a", statusCode: 500))
        await store.append(makeRecord(id: "three", sessionID: "session-b", statusCode: 201))

        let snapshot = await store.snapshot()
        let sessionA = snapshot.sessions.first(where: { $0.id == "session-a" })

        #expect(snapshot.sessions.count == 2)
        #expect(sessionA != nil)
        #expect(sessionA?.requestCount == 2)
        #expect(sessionA?.failureCount == 1)
    }

    @Test func transportFailuresWithoutHTTPResponseDoNotCreateSyntheticResponse() {
        let record = makeNetworkRecord(
            id: "offline",
            sessionID: "session-a",
            statusCode: -1,
            responseHeaders: nil,
            responseBody: nil,
            responseBodySize: nil,
            responseContentType: nil
        )

        let debugRecord = ApxyDebugRecord.make(
            record: record,
            metrics: nil,
            error: .init(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, message: "Offline")
        )

        #expect(debugRecord.response == nil)
    }

    @Test func httpStatusStillCreatesResponseWithoutHeadersOrBody() {
        let record = makeNetworkRecord(
            id: "empty-204",
            sessionID: "session-a",
            statusCode: 204,
            responseHeaders: nil,
            responseBody: nil,
            responseBodySize: nil,
            responseContentType: nil
        )

        let debugRecord = ApxyDebugRecord.make(record: record, metrics: nil, error: nil)

        #expect(debugRecord.response?.statusCode == 204)
    }

    private func makeStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("records.json")
    }

    private func makeRecord(
        id: String,
        sessionID: String,
        statusCode: Int = 200
    ) -> ApxyDebugRecord {
        ApxyDebugRecord(
            id: id,
            capturedAt: Date(),
            sessionID: sessionID,
            request: .init(
                method: "GET",
                url: "https://example.com/\(id)",
                host: "example.com",
                path: "/\(id)",
                headers: ["Accept": "application/json"],
                body: nil,
                bodySize: nil,
                contentType: nil,
                currentURL: nil,
                currentHost: nil,
                currentPath: nil,
                currentHeaders: [:]
            ),
            response: .init(
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"],
                body: Data("{\"id\":\"\(id)\"}".utf8),
                bodySize: 10,
                contentType: "application/json"
            ),
            transfer: .init(
                requestHeaderBytesSent: 10,
                requestBodyBytesBeforeEncoding: 0,
                requestBodyBytesSent: 0,
                responseHeaderBytesReceived: 12,
                responseBodyBytesReceived: 14,
                responseBodyBytesAfterDecoding: 14
            ),
            metrics: nil,
            error: nil,
            redirectCount: 0,
            duration: 0.5,
            isTLS: true,
            isMocked: false
        )
    }

    private func makeNetworkRecord(
        id: String,
        sessionID: String,
        statusCode: Int,
        responseHeaders: [String: String]?,
        responseBody: Data?,
        responseBodySize: Int64?,
        responseContentType: String?
    ) -> NetworkRecord {
        NetworkRecord(
            id: id,
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/\(id)",
            host: "example.com",
            path: "/\(id)",
            requestHeaders: ["Accept": "application/json"],
            requestBody: nil,
            requestBodySource: nil,
            requestBodySize: nil,
            requestContentType: nil,
            finalURL: nil,
            finalHost: nil,
            finalPath: nil,
            finalRequestHeaders: nil,
            statusCode: statusCode,
            responseHeaders: responseHeaders,
            responseBody: responseBody,
            responseBodySize: responseBodySize,
            responseContentType: responseContentType,
            redirectCount: 0,
            requestHeaderBytesSent: 10,
            requestBodyBytesBeforeEncoding: 0,
            requestBodyBytesSent: 0,
            responseHeaderBytesReceived: 12,
            responseBodyBytesReceived: responseBodySize,
            responseBodyBytesAfterDecoding: responseBodySize,
            duration: 500_000_000,
            tls: true,
            mocked: false,
            sessionID: sessionID
        )
    }
}

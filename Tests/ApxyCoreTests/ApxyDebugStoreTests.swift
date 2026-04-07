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

    @Test func sessionMetadataPersistsAndRestores() async throws {
        let fileURL = makeStoreURL()
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: fileURL
            )
        )

        let client = SDKClient(
            id: "client-1",
            platform: "ios",
            deviceModel: "iPhone",
            osName: "iOS",
            osVersion: "18.0",
            appBundleID: "dev.apxy.app",
            appVersion: "1.0",
            appBuild: "1",
            sdkVersion: "0.1.0",
            firstSeenAt: Date(timeIntervalSince1970: 100),
            lastSeenAt: Date(timeIntervalSince1970: 100)
        )
        let context = ClientContext(
            userID: "user-1",
            userEmail: "dev@example.com",
            userName: "Dev",
            networkType: "wifi",
            tags: ["env": "staging"],
            context: ["plan": "pro"]
        )

        await store.beginSession(
            id: "session-a",
            name: "SDK 2026-04-06 10:00:00",
            createdAt: Date(timeIntervalSince1970: 100),
            sdkClient: client,
            context: context,
            serverURL: nil,
            isLiveManaged: false
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
        let restoredSession = try #require(await restoredStore.localSessions().first)

        #expect(restoredSession.id == "session-a")
        #expect(restoredSession.sdkClient == client)
        #expect(restoredSession.context == context)
        #expect(restoredSession.requestCount == 1)
        #expect(restoredSession.syncState == .localOnly)
    }

    @Test func shareableSessionsExcludeLiveManagedSessions() async throws {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )

        let client = SDKClient(
            id: "client-1",
            platform: "ios",
            deviceModel: "iPhone",
            osName: "iOS",
            osVersion: "18.0",
            appBundleID: "dev.apxy.app",
            appVersion: "1.0",
            appBuild: "1",
            sdkVersion: "0.1.0",
            firstSeenAt: Date(timeIntervalSince1970: 100),
            lastSeenAt: Date(timeIntervalSince1970: 100)
        )

        await store.beginSession(
            id: "local-session",
            name: "Local",
            createdAt: Date(timeIntervalSince1970: 100),
            sdkClient: client,
            context: ClientContext(),
            serverURL: nil,
            isLiveManaged: false
        )
        await store.beginSession(
            id: "live-session",
            name: "Live",
            createdAt: Date(timeIntervalSince1970: 200),
            sdkClient: client,
            context: ClientContext(),
            serverURL: "http://127.0.0.1:8083",
            isLiveManaged: true
        )

        let shareableIDs = await store.shareableLocalSessions().map(\.id)
        #expect(shareableIDs == ["local-session"])
    }

    @Test func deleteSessionRemovesRecordsAndPersistence() async throws {
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
        await store.append(makeRecord(id: "two", sessionID: "session-b"))
        await store.deleteSession(id: "session-a")
        await store.flush()

        let snapshot = await store.snapshot()
        #expect(snapshot.sessions.map(\.id) == ["session-b"])
        #expect(snapshot.records.map(\.id) == ["two"])

        let restoredStore = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: fileURL
            )
        )
        let restoredSnapshot = await restoredStore.snapshot()

        #expect(restoredSnapshot.sessions.map(\.id) == ["session-b"])
        #expect(restoredSnapshot.records.map(\.id) == ["two"])
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

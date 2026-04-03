import Foundation
import Testing
@testable import ApxyCore
@testable import ApxyUI

struct ApxyDebugConsoleTests {
    @Test func filterMatchesStatusMethodHostSessionAndSearch() {
        let records = [
            makeRecord(
                id: "one",
                method: "GET",
                host: "api.example.com",
                sessionID: "session-a",
                statusCode: 200,
                body: Data("hello world".utf8)
            ),
            makeRecord(
                id: "two",
                method: "POST",
                host: "auth.example.com",
                sessionID: "session-b",
                statusCode: 500,
                body: Data("{\"error\":\"denied\"}".utf8)
            )
        ]

        let filtered = ApxyDebugFilterEngine.filter(
            records: records,
            using: ApxyDebugConsoleFilter(
                searchText: "denied",
                status: .failures,
                sessionID: "session-b",
                host: "auth.example.com",
                method: "POST"
            )
        )

        #expect(filtered.map(\.id) == ["two"])
    }

    @Test func bodyFormatterPrettyPrintsJSON() {
        let output = ApxyDebugBodyFormatter.displayText(
            data: Data("{\"b\":1,\"a\":2}".utf8),
            contentType: "application/json"
        )

        #expect(output?.contains("\n") == true)
        #expect(output?.contains("\"a\"") == true)
        #expect(output?.contains("\"b\"") == true)
    }

    @Test func viewModelReceivesStoreUpdates() async throws {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )
        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        await store.append(makeRecord(id: "one"))
        try await waitUntil {
            await MainActor.run { viewModel.records.count == 1 }
        }

        let selectedID = await MainActor.run { viewModel.selectedRecord?.id }
        #expect(selectedID == "one")
    }

    @Test func viewModelReconcilesSelectionWhenFiltersChange() async throws {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )
        await store.append(makeRecord(id: "one", statusCode: 200))
        await store.append(makeRecord(id: "two", statusCode: 500))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        await MainActor.run {
            viewModel.selectedRecordID = "one"
            viewModel.status = .failures
        }

        let selectedID = await MainActor.run { viewModel.selectedRecord?.id }
        #expect(selectedID == "two")
    }

    @Test @MainActor func activeFiltersIncludeSearchAndStructuredFilters() {
        let viewModel = ApxyDebugConsoleViewModel(
            store: ApxyDebugStore(
                options: ApxyDebugOptions(
                    isEnabled: true,
                    memoryRecordLimit: 10,
                    persistedRecordLimit: 10,
                    storeURL: makeStoreURL()
                )
            )
        )

        viewModel.searchText = "denied"
        viewModel.status = .failures
        viewModel.selectedSessionID = "session-a"
        viewModel.selectedHost = "api.example.com"
        viewModel.selectedMethod = "POST"

        #expect(viewModel.activeFilters == [
            "Failures",
            "Session session-",
            "api.example.com",
            "POST",
            "\"denied\""
        ])
    }

    @Test @MainActor func viewModelReleasesAfterGoingOutOfScope() async throws {
        let store = ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )
        weak var viewModel: ApxyDebugConsoleViewModel?
        do {
            let createdViewModel = ApxyDebugConsoleViewModel(store: store)
            viewModel = createdViewModel
        }
        let start = ContinuousClock.now
        while viewModel != nil {
            try await Task.sleep(nanoseconds: 20_000_000)
            if ContinuousClock.now - start > .seconds(1) {
                Issue.record("Timed out waiting for view model deallocation")
                break
            }
        }
        #expect(viewModel == nil)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let start = ContinuousClock.now
        while await !condition() {
            try await Task.sleep(nanoseconds: 20_000_000)
            if ContinuousClock.now - start > .nanoseconds(Int64(timeoutNanoseconds)) {
                Issue.record("Timed out waiting for condition")
                throw CancellationError()
            }
        }
    }

    private func makeStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("records.json")
    }

    private func makeRecord(
        id: String,
        method: String = "GET",
        host: String = "api.example.com",
        sessionID: String = "session-a",
        statusCode: Int = 200,
        body: Data? = Data("{\"hello\":\"world\"}".utf8)
    ) -> ApxyDebugRecord {
        ApxyDebugRecord(
            id: id,
            capturedAt: Date(),
            sessionID: sessionID,
            request: .init(
                method: method,
                url: "https://\(host)/\(id)",
                host: host,
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
                body: body,
                bodySize: body.map { Int64($0.count) },
                contentType: "application/json"
            ),
            transfer: .init(
                requestHeaderBytesSent: 12,
                requestBodyBytesBeforeEncoding: 0,
                requestBodyBytesSent: 0,
                responseHeaderBytesReceived: 18,
                responseBodyBytesReceived: body.map { Int64($0.count) },
                responseBodyBytesAfterDecoding: body.map { Int64($0.count) }
            ),
            metrics: nil,
            error: statusCode >= 400 ? .init(domain: "Test", code: statusCode, message: "Request failed") : nil,
            redirectCount: 0,
            duration: 0.25,
            isTLS: true,
            isMocked: false
        )
    }
}

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

    @Test func bodyFormatterMarksBinaryPayloads() {
        let output = ApxyDebugBodyFormatter.displayText(
            data: Data([0xFF, 0xD8, 0xFF, 0xE0]),
            contentType: "image/jpeg"
        )

        #expect(output?.contains("Binary body") == true)
    }

    @Test func bodyFormatterMarksUnavailablePayloads() {
        let presentation = ApxyDebugBodyFormatter.presentation(
            data: nil,
            contentType: "application/json",
            bodySize: 128
        )

        #expect(presentation == .unavailable)
        #expect(ApxyDebugBodyFormatter.displayText(data: nil, contentType: "application/json", bodySize: 128) == nil)
    }

    @Test func curlFormatterUsesCurrentRequestWhenRequested() {
        let record = makeRecord(
            id: "curl",
            method: "POST",
            host: "api.example.com",
            requestHeaders: ["Authorization": "Bearer token"],
            currentURL: "https://uploads.example.com/final",
            currentHost: "uploads.example.com",
            currentPath: "/final",
            currentHeaders: ["X-Trace": "abc123"],
            requestBody: Data("{\"hello\":\"world\"}".utf8)
        )

        let curl = ApxyDebugCurlFormatter.makeCurl(for: record, useCurrentRequest: true)

        #expect(curl.contains("'POST'"))
        #expect(curl.contains("'https://uploads.example.com/final'"))
        #expect(curl.contains("X-Trace: abc123"))
        #expect(curl.contains("--data-raw"))
    }

    @Test func cookiesFormatterParsesRequestAndResponseCookies() {
        let requestCookies = ApxyDebugCookiesFormatter.cookies(
            headers: ["Cookie": "session=abc; theme=dark"],
            urlString: "https://api.example.com/profile"
        )
        let responseCookies = ApxyDebugCookiesFormatter.cookies(
            headers: ["Set-Cookie": "refresh=xyz; Path=/; Secure"],
            urlString: "https://api.example.com/profile"
        )

        #expect(requestCookies.map(\.name) == ["session", "theme"])
        #expect(responseCookies.map(\.name) == ["refresh"])
        #expect(ApxyDebugCookiesFormatter.detailsText(for: requestCookies).contains("Name: session"))
    }

    @Test func recordExportFormatterProducesPrettyPrintedJSON() {
        let record = makeRecord(id: "json-export")
        let json = ApxyDebugRecordExportFormatter.jsonString(for: record)

        #expect(json?.contains("\n") == true)
        #expect(json?.contains("\"id\" : \"json-export\"") == true)
    }

    @Test func viewModelReceivesStoreUpdates() async throws {
        let store = makeStore()
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
        let store = makeStore()
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

    @Test func viewModelDerivesCountsFacetsAndSessionsFromSnapshot() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "older", method: "POST", host: "auth.example.com", sessionID: "session-b", statusCode: 503))
        await store.append(makeRecord(id: "newer", method: "GET", host: "api.example.com", sessionID: "session-a", statusCode: 200))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        let state = await MainActor.run {
            (
                viewModel.totalRecordCount,
                viewModel.visibleRecordCount,
                viewModel.failureCount,
                viewModel.hosts,
                viewModel.methods,
                viewModel.sessions.map(\.id),
                viewModel.selectedRecord?.id
            )
        }

        #expect(state.0 == 2)
        #expect(state.1 == 2)
        #expect(state.2 == 1)
        #expect(state.3 == ["api.example.com", "auth.example.com"])
        #expect(state.4 == ["GET", "POST"])
        #expect(state.5 == ["session-a", "session-b"])
        #expect(state.6 == "newer")
    }

    @Test func clearRemovesRecordsAndSelectionImmediately() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "one", statusCode: 200))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 1 }
        }

        await MainActor.run {
            viewModel.clear()
        }

        let state = await MainActor.run {
            (viewModel.records.isEmpty, viewModel.selectedRecord == nil, viewModel.totalRecordCount)
        }
        #expect(state.0)
        #expect(state.1)
        #expect(state.2 == 0)
    }

    @Test func viewModelHighlightsOnlyNewlyInsertedRecords() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "existing"))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 1 }
        }

        let initialHighlights = await MainActor.run { viewModel.highlightedRecordIDs }
        #expect(initialHighlights.isEmpty)

        await store.append(makeRecord(id: "new"))

        try await waitUntil {
            await MainActor.run { viewModel.highlightedRecordIDs.contains("new") }
        }
    }

    @Test @MainActor func activeFiltersIncludeSearchAndStructuredFilters() {
        let viewModel = ApxyDebugConsoleViewModel(
            store: makeStore()
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

    @Test @MainActor func clearFilterRemovesOnlyRequestedFilter() {
        let viewModel = ApxyDebugConsoleViewModel(
            store: makeStore()
        )

        viewModel.searchText = "denied"
        viewModel.status = .failures
        viewModel.selectedSessionID = "session-a"
        viewModel.selectedHost = "api.example.com"
        viewModel.selectedMethod = "POST"

        viewModel.clearFilter(.host)

        #expect(viewModel.selectedHost == nil)
        #expect(viewModel.selectedSessionID == "session-a")
        #expect(viewModel.selectedMethod == "POST")
        #expect(viewModel.status == .failures)
        #expect(viewModel.searchText == "denied")
    }

    @Test func filterStateClearRemovesOnlyRequestedDimension() {
        var filterState = ApxyDebugConsoleFilterState(
            searchText: "denied",
            status: .failures,
            selectedSessionID: "session-a",
            selectedHost: "api.example.com",
            selectedMethod: "POST"
        )

        filterState.clear(.host)

        #expect(filterState.selectedHost == nil)
        #expect(filterState.selectedSessionID == "session-a")
        #expect(filterState.selectedMethod == "POST")
        #expect(filterState.status == .failures)
        #expect(filterState.searchText == "denied")
    }

    @Test func resetFiltersClearsStructuredStateAndRestoresVisibleRecords() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "one", host: "api.example.com", statusCode: 200))
        await store.append(makeRecord(id: "two", host: "auth.example.com", statusCode: 500))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        await MainActor.run {
            viewModel.searchText = "failed"
            viewModel.status = .failures
            viewModel.selectedHost = "auth.example.com"
        }

        let filteredState = await MainActor.run {
            (viewModel.records.map(\.id), viewModel.visibleRecordCount)
        }
        #expect(filteredState.0 == ["two"])
        #expect(filteredState.1 == 1)

        await MainActor.run {
            viewModel.resetFilters()
        }

        let resetState = await MainActor.run {
            (
                viewModel.searchText,
                viewModel.status,
                viewModel.selectedHost,
                viewModel.selectedMethod,
                viewModel.selectedSessionID,
                viewModel.records.map(\.id),
                viewModel.visibleRecordCount
            )
        }
        #expect(resetState.0.isEmpty)
        #expect(resetState.1 == .all)
        #expect(resetState.2 == nil)
        #expect(resetState.3 == nil)
        #expect(resetState.4 == nil)
        #expect(resetState.5 == ["two", "one"])
        #expect(resetState.6 == 2)
    }

    @Test func resetFiltersRestoresVisibleRecordsAndKeepsValidSelection() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "success", statusCode: 200))
        await store.append(makeRecord(id: "failure", statusCode: 500))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        await MainActor.run {
            viewModel.selectedRecordID = "failure"
            viewModel.status = .failures
            viewModel.searchText = "Request failed"
        }

        try await waitUntil {
            await MainActor.run { viewModel.visibleRecordCount == 1 }
        }

        await MainActor.run {
            viewModel.resetFilters()
        }

        let state = await MainActor.run {
            (
                viewModel.status,
                viewModel.searchText,
                viewModel.visibleRecordCount,
                viewModel.totalRecordCount,
                viewModel.selectedRecord?.id
            )
        }

        #expect(state.0 == .all)
        #expect(state.1.isEmpty)
        #expect(state.2 == 2)
        #expect(state.3 == 2)
        #expect(state.4 == "failure")
    }

    @Test func prepareExportProducesShareableURL() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "export"))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 1 }
        }

        await MainActor.run {
            viewModel.prepareExport()
        }

        let exportURL = try await waitUntilValue {
            await MainActor.run { viewModel.exportURL }
        }
        let exportData = try Data(contentsOf: exportURL)

        #expect(exportData.isEmpty == false)
        let exportText = String(decoding: exportData, as: UTF8.self)
        #expect(exportText.contains("\"id\" : \"export\""))
        let exportError = await MainActor.run { viewModel.exportError }
        #expect(exportError == nil)
    }

    @Test func derivedStateReconcilesSelectionToVisibleRecords() {
        let records = [
            makeRecord(id: "one", statusCode: 200),
            makeRecord(id: "two", statusCode: 500)
        ]
        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: ApxyDebugSnapshot(records: records, sessions: []),
            filterState: ApxyDebugConsoleFilterState(status: .failures),
            selectedRecordID: "one",
            isClearing: false
        )

        #expect(derivedState.records.map(\.id) == ["two"])
        #expect(derivedState.selectedRecordID == "two")
        #expect(derivedState.selectedRecord?.id == "two")
    }

    @Test func viewModelPreservesVisibleSelectionWhenSnapshotAddsMatchingRecord() async throws {
        let store = makeStore()
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
            viewModel.status = .successes
        }

        let selectedBeforeUpdate = await MainActor.run { viewModel.selectedRecord?.id }
        #expect(selectedBeforeUpdate == "one")

        await store.append(makeRecord(id: "three", statusCode: 200))

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        let selectionAfterUpdate = await MainActor.run {
            (viewModel.records.map(\.id), viewModel.selectedRecord?.id, viewModel.selectedRecordID)
        }
        #expect(selectionAfterUpdate.0 == ["three", "one"])
        #expect(selectionAfterUpdate.1 == "one")
        #expect(selectionAfterUpdate.2 == "one")
    }

    @Test func prepareExportExportsOnlyVisibleFilteredRecords() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "success", statusCode: 200))
        await store.append(makeRecord(id: "failure", statusCode: 500))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        await MainActor.run {
            viewModel.status = .failures
            viewModel.prepareExport()
        }

        let exportURL = try await waitUntilValue {
            await MainActor.run { viewModel.exportURL }
        }
        let exportData = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedRecords = try decoder.decode([ApxyDebugRecord].self, from: exportData)

        #expect(exportedRecords.map(\.id) == ["failure"])
    }

    @Test @MainActor func navigationModelPushesStableCompactRouteAndPrunesMissingRecord() {
        let navigation = ApxyDebugNavigationModel()

        navigation.showRecord("one", usesCompactNavigation: true)

        #expect(navigation.compactPath == [.record("one")])
        #expect(navigation.compactRecordID == "one")

        let remainingRecords = [makeRecord(id: "two")]
        let reconciledSelection = navigation.reconcile(records: remainingRecords, selectedRecordID: nil)

        #expect(navigation.compactPath.isEmpty)
        #expect(reconciledSelection == "two")
    }

    @Test @MainActor func navigationModelReconcilesRegularSelectionToVisibleRecords() {
        let navigation = ApxyDebugNavigationModel()
        let records = [
            makeRecord(id: "one", statusCode: 200),
            makeRecord(id: "two", statusCode: 500)
        ]

        navigation.syncRegularSelection("one")
        let initialSelection = navigation.reconcile(records: records, selectedRecordID: "one")
        #expect(initialSelection == "one")

        let failuresOnlySelection = navigation.reconcile(records: [records[1]], selectedRecordID: "one")

        #expect(failuresOnlySelection == "two")
    }

    @Test @MainActor func viewModelReleasesAfterGoingOutOfScope() async throws {
        let store = makeStore()
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

    private func waitUntilValue<T: Sendable>(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        value: @escaping @Sendable () async -> T?
    ) async throws -> T {
        let start = ContinuousClock.now
        while let resolved = await value() {
            return resolved
        }

        while true {
            try await Task.sleep(nanoseconds: 20_000_000)
            if let resolved = await value() {
                return resolved
            }
            if ContinuousClock.now - start > .nanoseconds(Int64(timeoutNanoseconds)) {
                Issue.record("Timed out waiting for value")
                throw CancellationError()
            }
        }
    }

    private func makeStoreURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("records.json")
    }

    private func makeStore() -> ApxyDebugStore {
        ApxyDebugStore(
            options: ApxyDebugOptions(
                isEnabled: true,
                memoryRecordLimit: 10,
                persistedRecordLimit: 10,
                storeURL: makeStoreURL()
            )
        )
    }

    private func makeRecord(
        id: String,
        method: String = "GET",
        host: String = "api.example.com",
        sessionID: String = "session-a",
        statusCode: Int = 200,
        body: Data? = Data("{\"hello\":\"world\"}".utf8),
        requestHeaders: [String: String] = ["Accept": "application/json"],
        currentURL: String? = nil,
        currentHost: String? = nil,
        currentPath: String? = nil,
        currentHeaders: [String: String] = [:],
        requestBody: Data? = nil
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
                headers: requestHeaders,
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

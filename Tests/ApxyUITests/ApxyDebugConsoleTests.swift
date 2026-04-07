import Foundation
import SwiftUI
import Testing
@testable import ApxyCore
@testable import ApxyUI

@Suite(.serialized)
struct ApxyDebugConsoleTests {
    @Test func filterMatchesStatusMethodSessionAndSearch() {
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
                viewModel.methods,
                viewModel.sessions.map(\.id),
                viewModel.selectedRecord?.id
            )
        }

        #expect(state.0 == 2)
        #expect(state.1 == 2)
        #expect(state.2 == 1)
        #expect(state.3 == ["GET", "POST"])
        #expect(state.4 == ["session-a", "session-b"])
        #expect(state.5 == "newer")
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
        viewModel.selectedMethod = "POST"

        #expect(viewModel.activeFilters == [
            "Failures",
            "Session session-",
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
        viewModel.selectedMethod = "POST"

        viewModel.clearFilter(.method)

        #expect(viewModel.selectedMethod == nil)
        #expect(viewModel.selectedSessionID == "session-a")
        #expect(viewModel.status == .failures)
        #expect(viewModel.searchText == "denied")
    }

    @Test func filterStateClearRemovesOnlyRequestedDimension() {
        var filterState = ApxyDebugConsoleFilterState(
            searchText: "denied",
            status: .failures,
            selectedSessionID: "session-a",
            selectedMethod: "POST"
        )

        filterState.clear(.method)

        #expect(filterState.selectedMethod == nil)
        #expect(filterState.selectedSessionID == "session-a")
        #expect(filterState.status == .failures)
        #expect(filterState.searchText == "denied")
    }

    @Test func resetFiltersClearsStructuredStateAndRestoresVisibleRecords() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "one", method: "GET", host: "api.example.com", statusCode: 200))
        await store.append(makeRecord(id: "two", method: "POST", host: "auth.example.com", statusCode: 500))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        await MainActor.run {
            viewModel.searchText = "failed"
            viewModel.status = .failures
            viewModel.selectedMethod = "POST"
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
        #expect(resetState.4 == ["two", "one"])
        #expect(resetState.5 == 2)
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

    @Test func derivedStateReconcilesSelectionToVisibleRecords() {
        let records = [
            makeRecord(id: "one", statusCode: 200),
            makeRecord(id: "two", statusCode: 500)
        ]
        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: ApxyDebugSnapshot(records: records, sessions: []),
            scope: .all,
            filterState: ApxyDebugConsoleFilterState(status: .failures),
            selectedRecordID: "one"
        )

        #expect(derivedState.records.map(\.id) == ["two"])
        #expect(derivedState.selectedRecordID == "two")
        #expect(derivedState.selectedRecord?.id == "two")
    }

    @Test func derivedStateScopesLiveTrafficToNewestSession() {
        let olderRecord = makeRecord(
            id: "older",
            sessionID: "session-a",
            capturedAt: Date(timeIntervalSince1970: 10)
        )
        let newerRecord = makeRecord(
            id: "newer",
            sessionID: "session-b",
            capturedAt: Date(timeIntervalSince1970: 20)
        )
        let sessions = [
            ApxyDebugSession(
                id: "session-b",
                startedAt: Date(timeIntervalSince1970: 18),
                lastEventAt: Date(timeIntervalSince1970: 20),
                requestCount: 1,
                failureCount: 0
            ),
            ApxyDebugSession(
                id: "session-a",
                startedAt: Date(timeIntervalSince1970: 8),
                lastEventAt: Date(timeIntervalSince1970: 10),
                requestCount: 1,
                failureCount: 0
            )
        ]

        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: ApxyDebugSnapshot(records: [newerRecord, olderRecord], sessions: sessions),
            scope: .activeSession,
            filterState: .init(),
            selectedRecordID: nil
        )

        #expect(derivedState.records.map(\.id) == ["newer"])
        #expect(derivedState.totalRecordCount == 1)
        #expect(derivedState.selectedRecord?.id == "newer")
    }

    @Test func scopedViewModelFiltersToSelectedSessionAndKeepsSharedRequestFilters() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "session-a-success", host: "api.example.com", sessionID: "session-a", statusCode: 200))
        await store.append(makeRecord(id: "session-a-failure", host: "auth.example.com", sessionID: "session-a", statusCode: 500))
        await store.append(makeRecord(id: "session-b-failure", host: "auth.example.com", sessionID: "session-b", statusCode: 500))

        let viewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store, scope: .session("session-a"))
        }

        try await waitUntil {
            await MainActor.run { viewModel.records.count == 2 }
        }

        await MainActor.run {
            viewModel.status = .failures
            viewModel.selectedSessionID = "session-b"
        }

        let state = await MainActor.run {
            (
                viewModel.records.map(\.id),
                viewModel.totalRecordCount,
                viewModel.visibleRecordCount,
                viewModel.selectedSessionID
            )
        }

        #expect(state.0 == ["session-a-failure"])
        #expect(state.1 == 2)
        #expect(state.2 == 1)
        #expect(state.3 == nil)
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

    @Test @MainActor func navigationModelPresentsCompactDetailAndPrunesMissingRecord() {
        let navigation = ApxyDebugNavigationCoordinator()

        navigation.showRecord("one", usesCompactNavigation: true)

        #expect(navigation.compactRecordID == "one")
        #expect(navigation.isShowingCompactDetail == true)

        let remainingRecords = [makeRecord(id: "two")]
        let reconciledSelection = navigation.reconcile(records: remainingRecords, selectedRecordID: nil)

        #expect(navigation.compactRecordID == nil)
        #expect(navigation.isShowingCompactDetail == false)
        #expect(reconciledSelection == "two")
    }

    @Test @MainActor func navigationModelReconcilesRegularSelectionToVisibleRecords() {
        let navigation = ApxyDebugNavigationCoordinator()
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

    @Test @MainActor func runtimeSettingsViewModelReflectsAndAppliesActiveConfig() {
        Apxy.stop()
        Apxy.start()

        let viewModel = ApxyDebugRuntimeSettingsViewModel()
        #expect(viewModel.activeSummary.contains("local-only"))

        viewModel.serverURL = "http://127.0.0.1:8083"
        viewModel.flushIntervalText = "4.5"
        viewModel.capturedDomainsText = "api.example.com, *.example.com"
        viewModel.applyChanges()

        #expect(Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
            serverURL: "http://127.0.0.1:8083",
            flushInterval: 4.5,
            capturedDomains: ["api.example.com", "*.example.com"]
        ))
        #expect(viewModel.activeSummary.contains("http://127.0.0.1:8083"))

        Apxy.stop()
    }

    @Test @MainActor func runtimeSettingsViewModelRejectsInvalidFlushInterval() {
        Apxy.stop()
        Apxy.start()

        let viewModel = ApxyDebugRuntimeSettingsViewModel()
        viewModel.flushIntervalText = "zero"
        viewModel.applyChanges()

        #expect(viewModel.applyStatus == "Enter a valid flush interval (> 0).")
        #expect(Apxy.activeRuntimeConfiguration == ApxyRuntimeConfiguration(
            serverURL: nil,
            flushInterval: 2.0,
            capturedDomains: nil
        ))

        Apxy.stop()
    }

    @Test func runtimeSettingsViewModelClearsDebugStoreData() async throws {
        let store = makeStore()
        await store.append(makeRecord(id: "one", sessionID: "session-a"))
        await store.append(makeRecord(id: "two", sessionID: "session-b"))

        let consoleViewModel = await MainActor.run {
            ApxyDebugConsoleViewModel(store: store)
        }

        try await waitUntil {
            await MainActor.run { consoleViewModel.records.count == 2 }
        }

        let settingsViewModel = await MainActor.run {
            ApxyDebugRuntimeSettingsViewModel(debugStore: store)
        }

        await MainActor.run {
            settingsViewModel.clearAllData()
        }

        try await waitUntil {
            await MainActor.run {
                consoleViewModel.records.isEmpty
                    && settingsViewModel.applyStatus == "Cleared all captured sessions and requests."
                    && settingsViewModel.applyStatusKind == .success
                    && settingsViewModel.isClearingData == false
            }
        }
    }

    @Test func themeUsesWebsiteLightTokensAndDocumentedDarkTokens() {
        let light = ApxyDebugTheme.tokens(for: .light)
        let dark = ApxyDebugTheme.tokens(for: .dark)

        #expect(light.backgroundPrimary == 0xFFFFFF)
        #expect(light.backgroundSecondary == 0xF5F4ED)
        #expect(light.accent == 0xD97757)
        #expect(dark.backgroundPrimary == 0x0A0A0A)
        #expect(dark.backgroundSecondary == 0x111111)
        #expect(dark.accent == 0x3B82F6)
    }

    @Test func statusPresentationMapsToSemanticThemeTones() {
        let success = ApxyDebugStatusPresentation.from(record: makeRecord(id: "success", statusCode: 204))
        var failureRecord = makeRecord(id: "failure", statusCode: 500)
        failureRecord.error = nil
        let failure = ApxyDebugStatusPresentation.from(record: failureRecord)
        let pending = ApxyDebugStatusPresentation.from(record: makeRecord(id: "pending", statusCode: 102))

        #expect(success.tone == .success)
        #expect(success.iconName == "checkmark.circle.fill")
        #expect(failure.tone == .error)
        #expect(failure.iconName == "exclamationmark.triangle.fill")
        #expect(pending.tone == .warning)
        #expect(pending.iconName == "clock.fill")
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
        capturedAt: Date = Date(),
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
            capturedAt: capturedAt,
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

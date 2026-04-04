import Foundation
import ApxyCore

struct ApxyDebugConsoleViewState {
    var snapshot: ApxyDebugSnapshot = .empty
    var filterState = ApxyDebugConsoleFilterState()
    var records: [ApxyDebugRecord] = []
    var sessions: [ApxyDebugSession] = []
    var totalRecordCount = 0
    var visibleRecordCount = 0
    var failureCount = 0
    var hosts: [String] = []
    var methods: [String] = []
    var selectedRecordID: String?
    var selectedRecord: ApxyDebugRecord?
    var exportURL: URL?
    var exportError: String?
    var highlightedRecordIDs: Set<String> = []
    var isClearing = false

    var successCount: Int {
        totalRecordCount - failureCount
    }

    var activeFilters: [String] {
        filterState.activeFilterItems.map(\.title)
    }

    var activeFilterItems: [ApxyDebugConsoleActiveFilterItem] {
        filterState.activeFilterItems
    }

    mutating func apply(_ derivedState: ApxyDebugConsoleDerivedState) {
        sessions = derivedState.sessions
        totalRecordCount = derivedState.totalRecordCount
        failureCount = derivedState.failureCount
        hosts = derivedState.hosts
        methods = derivedState.methods
        records = derivedState.records
        visibleRecordCount = derivedState.visibleRecordCount
        selectedRecordID = derivedState.selectedRecordID
        selectedRecord = derivedState.selectedRecord
    }

    mutating func resetVisibleStateForClear() {
        isClearing = true
        exportURL = nil
        selectedRecordID = nil
        selectedRecord = nil
        snapshot = .empty
        records = []
        sessions = []
        totalRecordCount = 0
        visibleRecordCount = 0
        failureCount = 0
        hosts = []
        methods = []
        highlightedRecordIDs = []
    }

    mutating func setExportResult(url: URL) {
        exportURL = url
        exportError = nil
    }

    mutating func setExportError(_ message: String) {
        exportError = message
    }
}

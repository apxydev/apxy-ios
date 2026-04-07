import ApxyCore

struct ApxyDebugConsoleViewState {
    var snapshot: ApxyDebugSnapshot = .empty
    var filterState = ApxyDebugConsoleFilterState()
    var records: [ApxyDebugRecord] = []
    var sessions: [ApxyDebugSession] = []
    var totalRecordCount = 0
    var visibleRecordCount = 0
    var failureCount = 0
    var methods: [String] = []
    var selectedRecordID: String?
    var selectedRecord: ApxyDebugRecord?
    var highlightedRecordIDs: Set<String> = []

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
        methods = derivedState.methods
        records = derivedState.records
        visibleRecordCount = derivedState.visibleRecordCount
        selectedRecordID = derivedState.selectedRecordID
        selectedRecord = derivedState.selectedRecord
    }
}

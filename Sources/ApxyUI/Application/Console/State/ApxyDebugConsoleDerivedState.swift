import Foundation
import ApxyCore

struct ApxyDebugConsoleDerivedState {
    let records: [ApxyDebugRecord]
    let sessions: [ApxyDebugSession]
    let totalRecordCount: Int
    let visibleRecordCount: Int
    let failureCount: Int
    let methods: [String]
    let selectedRecordID: String?
    let selectedRecord: ApxyDebugRecord?

    static func make(
        snapshot: ApxyDebugSnapshot,
        scope: ApxyDebugConsoleScope,
        filterState: ApxyDebugConsoleFilterState,
        selectedRecordID: String?
    ) -> ApxyDebugConsoleDerivedState {
        let scopedRecords = scope.scopedRecords(in: snapshot)
        let filteredRecords = ApxyDebugFilterEngine.filter(
            records: scopedRecords,
            using: filterState.consoleFilter
        )
        let selection = resolveSelection(
            records: filteredRecords,
            selectedRecordID: selectedRecordID
        )

        return ApxyDebugConsoleDerivedState(
            records: filteredRecords,
            sessions: snapshot.sessions,
            totalRecordCount: scopedRecords.count,
            visibleRecordCount: filteredRecords.count,
            failureCount: scopedRecords.lazy.filter(\.isFailure).count,
            methods: Array(Set(scopedRecords.lazy.map(\.request.method))).sorted(),
            selectedRecordID: selection.id,
            selectedRecord: selection.record
        )
    }

    private static func resolveSelection(
        records: [ApxyDebugRecord],
        selectedRecordID: String?
    ) -> (id: String?, record: ApxyDebugRecord?) {
        let availableIDs = Set(records.lazy.map(\.id))
        guard !availableIDs.isEmpty else {
            return (nil, nil)
        }

        if let selectedRecordID, availableIDs.contains(selectedRecordID) {
            return (selectedRecordID, records.first(where: { $0.id == selectedRecordID }))
        }

        return (records.first?.id, records.first)
    }
}

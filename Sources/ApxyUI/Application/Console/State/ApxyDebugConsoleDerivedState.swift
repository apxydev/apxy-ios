import Foundation
import ApxyCore

struct ApxyDebugConsoleDerivedState {
    let records: [ApxyDebugRecord]
    let sessions: [ApxyDebugSession]
    let totalRecordCount: Int
    let visibleRecordCount: Int
    let failureCount: Int
    let hosts: [String]
    let methods: [String]
    let selectedRecordID: String?
    let selectedRecord: ApxyDebugRecord?

    static func make(
        snapshot: ApxyDebugSnapshot,
        filterState: ApxyDebugConsoleFilterState,
        selectedRecordID: String?,
        isClearing: Bool
    ) -> ApxyDebugConsoleDerivedState {
        let filteredRecords = ApxyDebugFilterEngine.filter(
            records: snapshot.records,
            using: filterState.consoleFilter
        )
        let selection = resolveSelection(
            records: filteredRecords,
            selectedRecordID: selectedRecordID,
            isClearing: isClearing
        )

        return ApxyDebugConsoleDerivedState(
            records: filteredRecords,
            sessions: snapshot.sessions,
            totalRecordCount: snapshot.records.count,
            visibleRecordCount: filteredRecords.count,
            failureCount: snapshot.records.lazy.filter(\.isFailure).count,
            hosts: Array(Set(snapshot.records.lazy.map(\.request.host))).sorted(),
            methods: Array(Set(snapshot.records.lazy.map(\.request.method))).sorted(),
            selectedRecordID: selection.id,
            selectedRecord: selection.record
        )
    }

    private static func resolveSelection(
        records: [ApxyDebugRecord],
        selectedRecordID: String?,
        isClearing: Bool
    ) -> (id: String?, record: ApxyDebugRecord?) {
        guard !isClearing else {
            return (nil, nil)
        }

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

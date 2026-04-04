import Foundation
import ApxyCore

enum ApxyDebugConsoleHighlighter {
    static func insertedRecordIDs(
        from previousRecords: [ApxyDebugRecord],
        to newRecords: [ApxyDebugRecord]
    ) -> Set<String> {
        guard !previousRecords.isEmpty else { return [] }
        let previousIDs = Set(previousRecords.map(\.id))
        return Set(newRecords.map(\.id)).subtracting(previousIDs)
    }
}

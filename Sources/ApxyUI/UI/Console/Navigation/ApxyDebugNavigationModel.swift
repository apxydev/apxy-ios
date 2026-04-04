import Foundation
import ApxyCore

@MainActor
final class ApxyDebugNavigationModel: ObservableObject {
    @Published var compactPath: [ApxyDebugConsoleRoute] = []
    @Published private(set) var regularSelectionID: String?

    var compactRecordID: String? {
        compactPath.last?.recordID
    }

    func showRecord(_ recordID: String, usesCompactNavigation: Bool) {
        if usesCompactNavigation {
            compactPath = [.record(recordID)]
            return
        }
        regularSelectionID = recordID
    }

    func syncRegularSelection(_ recordID: String?) {
        regularSelectionID = recordID
    }

    @discardableResult
    func reconcile(records: [ApxyDebugRecord], selectedRecordID: String?) -> String? {
        let availableIDs = Set(records.map(\.id))

        if let compactRecordID, !availableIDs.contains(compactRecordID) {
            compactPath.removeAll()
        }

        guard !records.isEmpty else {
            regularSelectionID = nil
            return nil
        }

        if let selectedRecordID, availableIDs.contains(selectedRecordID) {
            regularSelectionID = selectedRecordID
            return selectedRecordID
        }

        let fallbackID = records.first?.id
        regularSelectionID = fallbackID
        return fallbackID
    }

    func record(for route: ApxyDebugConsoleRoute, in records: [ApxyDebugRecord]) -> ApxyDebugRecord? {
        records.first(where: { $0.id == route.recordID })
    }

    func clear() {
        compactPath.removeAll()
        regularSelectionID = nil
    }
}

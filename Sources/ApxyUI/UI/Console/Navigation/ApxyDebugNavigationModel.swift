import Foundation
import ApxyCore

@MainActor
final class ApxyDebugNavigationModel: ObservableObject {
    @Published private(set) var compactRecordID: String?
    @Published private(set) var isShowingCompactDetail = false
    @Published private(set) var regularSelectionID: String?

    func showRecord(_ recordID: String, usesCompactNavigation: Bool) {
        if usesCompactNavigation {
            compactRecordID = recordID
            isShowingCompactDetail = true
            return
        }
        regularSelectionID = recordID
    }

    func setCompactDetailPresented(_ isPresented: Bool) {
        isShowingCompactDetail = isPresented
        if !isPresented {
            compactRecordID = nil
        }
    }

    func syncRegularSelection(_ recordID: String?) {
        regularSelectionID = recordID
    }

    @discardableResult
    func reconcile(records: [ApxyDebugRecord], selectedRecordID: String?) -> String? {
        let availableIDs = Set(records.map(\.id))

        if let compactRecordID, !availableIDs.contains(compactRecordID) {
            setCompactDetailPresented(false)
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
        setCompactDetailPresented(false)
        regularSelectionID = nil
    }
}

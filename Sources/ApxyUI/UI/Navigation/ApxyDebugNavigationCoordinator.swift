import Foundation
import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class ApxyDebugNavigationCoordinator: ObservableObject {
    @Published var compactPath = NavigationPath()
    @Published private(set) var compactRecordID: String?
    @Published private(set) var regularSelectionID: String?
    @Published var inspectorPath = NavigationPath()

    var compactPathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.compactPath },
            set: { newPath in
                self.compactPath = newPath
                if newPath.isEmpty {
                    self.compactRecordID = nil
                }
            }
        )
    }

    var inspectorPathBinding: Binding<NavigationPath> {
        Binding(
            get: { self.inspectorPath },
            set: { self.inspectorPath = $0 }
        )
    }

    var isShowingCompactDetail: Bool { !compactPath.isEmpty }

    func showRecord(_ recordID: String, usesCompactNavigation: Bool) {
        if usesCompactNavigation {
            compactRecordID = recordID
            compactPath.append(ApxyDebugRoute.record(recordID))
            return
        }
        if regularSelectionID != recordID {
            resetInspectorPath()
        }
        regularSelectionID = recordID
    }

    func setCompactDetailPresented(_ isPresented: Bool) {
        if !isPresented {
            compactPath = NavigationPath()
            compactRecordID = nil
        }
    }

    func syncRegularSelection(_ recordID: String?) {
        if regularSelectionID != recordID {
            resetInspectorPath()
        }
        regularSelectionID = recordID
    }

    func resetInspectorPath() {
        inspectorPath = NavigationPath()
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
        if regularSelectionID != fallbackID {
            resetInspectorPath()
        }
        regularSelectionID = fallbackID
        return fallbackID
    }

    func record(for route: ApxyDebugRoute, in records: [ApxyDebugRecord]) -> ApxyDebugRecord? {
        records.first(where: { $0.id == route.recordID })
    }

    func clear() {
        setCompactDetailPresented(false)
        regularSelectionID = nil
        resetInspectorPath()
    }
}

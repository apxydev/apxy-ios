import SwiftUI
@preconcurrency import Combine
import ApxyCore

@MainActor
final class ApxyDebugConsoleScreenModel: ObservableObject {
    let viewModel: ApxyDebugConsoleViewModel
    private let navigationModel = ApxyDebugNavigationModel()
    private var changeCancellables: Set<AnyCancellable> = []

    init(store: ApxyDebugStore) {
        self.viewModel = ApxyDebugConsoleViewModel(store: store)
        bindChildChanges()
    }

    var records: [ApxyDebugRecord] { viewModel.records }
    var selectedRecordID: String? { viewModel.selectedRecordID }
    var selectedRecord: ApxyDebugRecord? { viewModel.selectedRecord }
    var exportError: String? { viewModel.exportError }
    var exportURL: URL? { viewModel.exportURL }
    var totalRecordCount: Int { viewModel.totalRecordCount }
    var visibleRecordCount: Int { viewModel.visibleRecordCount }
    var failureCount: Int { viewModel.failureCount }
    var activeFilters: [String] { viewModel.activeFilters }
    var highlightedRecordIDs: Set<String> { viewModel.highlightedRecordIDs }
    var sessions: [ApxyDebugSession] { viewModel.sessions }
    var hosts: [String] { viewModel.hosts }
    var methods: [String] { viewModel.methods }
    var compactPath: [ApxyDebugConsoleRoute] { navigationModel.compactPath }
    var compactRecordID: String? { navigationModel.compactRecordID }

    var searchTextBinding: Binding<String> {
        Binding(
            get: { self.viewModel.searchText },
            set: { self.viewModel.searchText = $0 }
        )
    }

    var statusBinding: Binding<ApxyDebugStatusFilter> {
        Binding(
            get: { self.viewModel.status },
            set: { self.viewModel.status = $0 }
        )
    }

    var selectedSessionIDBinding: Binding<String?> {
        Binding(
            get: { self.viewModel.selectedSessionID },
            set: { self.viewModel.selectedSessionID = $0 }
        )
    }

    var selectedHostBinding: Binding<String?> {
        Binding(
            get: { self.viewModel.selectedHost },
            set: { self.viewModel.selectedHost = $0 }
        )
    }

    var selectedMethodBinding: Binding<String?> {
        Binding(
            get: { self.viewModel.selectedMethod },
            set: { self.viewModel.selectedMethod = $0 }
        )
    }

    var compactPathBinding: Binding<[ApxyDebugConsoleRoute]> {
        Binding(
            get: { self.navigationModel.compactPath },
            set: { self.navigationModel.compactPath = $0 }
        )
    }

    var regularSelectionBinding: Binding<String?> {
        Binding(
            get: { self.navigationModel.regularSelectionID ?? self.viewModel.selectedRecordID },
            set: { newValue in
                self.navigationModel.syncRegularSelection(newValue)
                self.viewModel.selectedRecordID = newValue
            }
        )
    }

    func dismissExportError() {
        viewModel.dismissExportError()
    }

    func resetFilters() {
        viewModel.resetFilters()
    }

    func prepareExport() {
        viewModel.prepareExport()
    }

    func clearRecords() {
        navigationModel.clear()
        viewModel.clear()
    }

    func record(for route: ApxyDebugConsoleRoute) -> ApxyDebugRecord? {
        navigationModel.record(for: route, in: viewModel.records)
    }

    func selectRecord(_ record: ApxyDebugRecord, usesCompactNavigation: Bool) {
        viewModel.selectedRecordID = record.id
        navigationModel.showRecord(record.id, usesCompactNavigation: usesCompactNavigation)
    }

    func syncRegularSelectionIfNeeded(usesCompactNavigation: Bool) {
        guard !usesCompactNavigation else { return }
        navigationModel.syncRegularSelection(viewModel.selectedRecordID)
    }

    func syncCompactSelectionIfNeeded(usesCompactNavigation: Bool) {
        guard usesCompactNavigation else { return }
        if let compactRecordID,
           compactRecordID != viewModel.selectedRecordID {
            viewModel.selectedRecordID = compactRecordID
        }
    }

    func reconcileNavigation(usesCompactNavigation: Bool) {
        let selectedRecordID = navigationModel.reconcile(
            records: viewModel.records,
            selectedRecordID: viewModel.selectedRecordID
        )

        if !usesCompactNavigation, selectedRecordID != viewModel.selectedRecordID {
            viewModel.selectedRecordID = selectedRecordID
        }

        if usesCompactNavigation,
           let compactRecordID,
           compactRecordID != viewModel.selectedRecordID {
            viewModel.selectedRecordID = compactRecordID
        }
    }

    private func bindChildChanges() {
        viewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &changeCancellables)

        navigationModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &changeCancellables)
    }
}

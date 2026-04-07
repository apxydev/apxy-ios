import SwiftUI
@preconcurrency import Combine
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class ApxyDebugConsoleScreenModel: ObservableObject {
    let viewModel: ApxyDebugConsoleViewModel
    private let scope: ApxyDebugConsoleScope
    private let coordinator = ApxyDebugNavigationCoordinator()
    private var changeCancellables: Set<AnyCancellable> = []

    init(
        store: ApxyDebugStore,
        scope: ApxyDebugConsoleScope
    ) {
        self.scope = scope
        self.viewModel = ApxyDebugConsoleViewModel(store: store, scope: scope)
        bindChildChanges()
    }

    var records: [ApxyDebugRecord] { viewModel.records }
    var selectedRecordID: String? { viewModel.selectedRecordID }
    var selectedRecord: ApxyDebugRecord? { viewModel.selectedRecord }
    var totalRecordCount: Int { viewModel.totalRecordCount }
    var visibleRecordCount: Int { viewModel.visibleRecordCount }
    var failureCount: Int { viewModel.failureCount }
    var activeFilters: [String] { viewModel.activeFilters }
    var highlightedRecordIDs: Set<String> { viewModel.highlightedRecordIDs }
    var sessions: [ApxyDebugSession] { viewModel.sessions }
    var hosts: [String] { viewModel.hosts }
    var methods: [String] { viewModel.methods }
    var compactRecordID: String? { coordinator.compactRecordID }
    var isShowingCompactDetail: Bool { coordinator.isShowingCompactDetail }
    var showsSessionFilter: Bool { scope.allowsSessionSelection }

    var selectedScopeSession: ApxyDebugSession? {
        guard let sessionID = scope.resolvedSessionID(in: viewModel.snapshot) else { return nil }
        return sessions.first(where: { $0.id == sessionID })
    }

    var navigationTitle: String {
        switch scope {
        case .all:
            return "Requests"
        case .activeSession:
            return "Live Traffic"
        case let .session(sessionID):
            let titleID = selectedScopeSession?.id ?? sessionID
            return "Session \(String(titleID.prefix(8)))"
        }
    }

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

    var compactPathBinding: Binding<NavigationPath> {
        coordinator.compactPathBinding
    }

    var compactDetailPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.coordinator.isShowingCompactDetail },
            set: { self.coordinator.setCompactDetailPresented($0) }
        )
    }

    var inspectorPathBinding: Binding<NavigationPath> {
        coordinator.inspectorPathBinding
    }

    var regularSelectionBinding: Binding<String?> {
        Binding(
            get: { self.coordinator.regularSelectionID ?? self.viewModel.selectedRecordID },
            set: { newValue in
                self.coordinator.syncRegularSelection(newValue)
                self.viewModel.selectedRecordID = newValue
            }
        )
    }

    func resetFilters() {
        viewModel.resetFilters()
    }

    func clearRecords() {
        coordinator.clear()
        viewModel.clear()
    }

    func record(for route: ApxyDebugRoute) -> ApxyDebugRecord? {
        coordinator.record(for: route, in: viewModel.records)
    }

    var compactSelectedRecord: ApxyDebugRecord? {
        guard let compactRecordID else { return nil }
        return viewModel.records.first(where: { $0.id == compactRecordID })
    }

    func selectRecord(_ record: ApxyDebugRecord, usesCompactNavigation: Bool) {
        viewModel.selectedRecordID = record.id
        coordinator.showRecord(record.id, usesCompactNavigation: usesCompactNavigation)
    }

    func syncRegularSelectionIfNeeded(usesCompactNavigation: Bool) {
        guard !usesCompactNavigation else { return }
        coordinator.syncRegularSelection(viewModel.selectedRecordID)
    }

    func reconcileNavigation(usesCompactNavigation: Bool) {
        let selectedRecordID = coordinator.reconcile(
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

        coordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &changeCancellables)
    }
}

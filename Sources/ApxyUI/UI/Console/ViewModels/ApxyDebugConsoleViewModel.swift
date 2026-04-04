import Foundation
@preconcurrency import Combine
import ApxyCore

@MainActor
public final class ApxyDebugConsoleViewModel: ObservableObject {
    typealias ActiveFilterItem = ApxyDebugConsoleActiveFilterItem

    @Published var searchText: String {
        didSet {
            interactor.setSearchText(searchText)
        }
    }

    private let interactor: ApxyDebugConsoleInteractor
    private var changeCancellables: Set<AnyCancellable> = []

    public init(store: ApxyDebugStore) {
        let interactor = ApxyDebugConsoleInteractor(store: store)
        self.interactor = interactor
        self.searchText = interactor.state.filterState.searchText

        bindInteractor()
    }

    var status: ApxyDebugStatusFilter {
        get { interactor.state.filterState.status }
        set { interactor.setStatus(newValue) }
    }

    var selectedSessionID: String? {
        get { interactor.state.filterState.selectedSessionID }
        set { interactor.setSelectedSessionID(newValue) }
    }

    var selectedHost: String? {
        get { interactor.state.filterState.selectedHost }
        set { interactor.setSelectedHost(newValue) }
    }

    var selectedMethod: String? {
        get { interactor.state.filterState.selectedMethod }
        set { interactor.setSelectedMethod(newValue) }
    }

    var selectedRecordID: String? {
        get { interactor.state.selectedRecordID }
        set { interactor.setSelectedRecordID(newValue) }
    }

    var snapshot: ApxyDebugSnapshot {
        interactor.state.snapshot
    }

    var records: [ApxyDebugRecord] {
        interactor.state.records
    }

    var sessions: [ApxyDebugSession] {
        interactor.state.sessions
    }

    var totalRecordCount: Int {
        interactor.state.totalRecordCount
    }

    var visibleRecordCount: Int {
        interactor.state.visibleRecordCount
    }

    var failureCount: Int {
        interactor.state.failureCount
    }

    var hosts: [String] {
        interactor.state.hosts
    }

    var methods: [String] {
        interactor.state.methods
    }

    var selectedRecord: ApxyDebugRecord? {
        interactor.state.selectedRecord
    }

    var exportURL: URL? {
        interactor.state.exportURL
    }

    var exportError: String? {
        interactor.state.exportError
    }

    var highlightedRecordIDs: Set<String> {
        interactor.state.highlightedRecordIDs
    }

    var successCount: Int {
        interactor.state.successCount
    }

    var activeFilters: [String] {
        interactor.state.activeFilters
    }

    var activeFilterItems: [ActiveFilterItem] {
        interactor.state.activeFilterItems
    }

    func clearFilter(_ kind: ActiveFilterItem.Kind) {
        if kind == .search, !searchText.isEmpty {
            searchText = ""
        }
        interactor.clearFilter(kind)
    }

    func clear() {
        interactor.clear()
    }

    func resetFilters() {
        if !searchText.isEmpty {
            searchText = ""
        }
        interactor.resetFilters()
    }

    func prepareExport() {
        interactor.prepareExport()
    }

    func dismissExportError() {
        interactor.dismissExportError()
    }

    private func bindInteractor() {
        interactor.$state
            .dropFirst()
            .sink { [weak self] state in
                guard let self else { return }
                if self.searchText != state.filterState.searchText {
                    self.searchText = state.filterState.searchText
                }
                self.objectWillChange.send()
            }
            .store(in: &changeCancellables)
    }
}

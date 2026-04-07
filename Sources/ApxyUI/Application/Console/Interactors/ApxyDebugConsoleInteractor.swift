import Foundation
@preconcurrency import Combine
import ApxyCore

@MainActor
final class ApxyDebugConsoleInteractor: ObservableObject {
    @Published private(set) var state = ApxyDebugConsoleViewState()

    private let store: ApxyDebugStore
    private let scope: ApxyDebugConsoleScope
    private var updatesTask: Task<Void, Never>?

    init(
        store: ApxyDebugStore,
        scope: ApxyDebugConsoleScope = .all
    ) {
        self.store = store
        self.scope = scope
        observeStore()
    }

    deinit {
        updatesTask?.cancel()
    }

    func setSearchText(_ searchText: String) {
        updateFilterState {
            $0.searchText = searchText
        }
    }

    func setStatus(_ status: ApxyDebugStatusFilter) {
        updateFilterState {
            $0.status = status
        }
    }

    func setSelectedSessionID(_ sessionID: String?) {
        guard scope.allowsSessionSelection else { return }
        updateFilterState {
            $0.selectedSessionID = sessionID
        }
    }

    func setSelectedMethod(_ method: String?) {
        updateFilterState {
            $0.selectedMethod = method
        }
    }

    func setSelectedRecordID(_ recordID: String?) {
        state.selectedRecordID = recordID
        syncSelectedRecord()
    }

    func clearFilter(_ kind: ApxyDebugConsoleActiveFilterItem.Kind) {
        updateFilterState {
            $0.clear(kind)
        }
    }

    func resetFilters() {
        applyFilterState(.init())
    }

    func clear() {
        Task { [store] in
            await store.clear()
        }
    }

    func deleteSession(id sessionID: String) {
        Task { [store] in
            await store.deleteSession(id: sessionID)
        }
    }

    private func observeStore() {
        updatesTask = Task { [weak self, store] in
            let stream = await store.updates()
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                self?.handle(snapshot: snapshot)
            }
        }
    }

    private func handle(snapshot: ApxyDebugSnapshot) {
        let insertedIDs = ApxyDebugConsoleHighlighter.insertedRecordIDs(
            from: state.snapshot.records,
            to: snapshot.records
        )
        if !insertedIDs.isEmpty {
            state.highlightedRecordIDs.formUnion(insertedIDs)
            scheduleHighlightRemoval(for: insertedIDs)
        }

        state.snapshot = snapshot
        refreshDerivedState()
    }

    private func refreshDerivedState() {
        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: state.snapshot,
            scope: scope,
            filterState: state.filterState,
            selectedRecordID: state.selectedRecordID
        )

        state.apply(derivedState)
    }

    private func syncSelectedRecord() {
        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: state.snapshot,
            scope: scope,
            filterState: state.filterState,
            selectedRecordID: state.selectedRecordID
        )

        if state.selectedRecordID != derivedState.selectedRecordID {
            state.selectedRecordID = derivedState.selectedRecordID
            return
        }

        state.selectedRecord = derivedState.selectedRecord
    }

    private func updateFilterState(_ update: (inout ApxyDebugConsoleFilterState) -> Void) {
        var nextState = state.filterState
        update(&nextState)
        applyFilterState(nextState)
    }

    private func applyFilterState(_ filterState: ApxyDebugConsoleFilterState) {
        state.filterState = filterState
        refreshDerivedState()
    }

    private func scheduleHighlightRemoval(for insertedIDs: Set<String>) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard let self else { return }
            self.state.highlightedRecordIDs.subtract(insertedIDs)
        }
    }
}

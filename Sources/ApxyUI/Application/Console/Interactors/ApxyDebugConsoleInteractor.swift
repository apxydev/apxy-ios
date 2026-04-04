import Foundation
@preconcurrency import Combine
import ApxyCore

@MainActor
final class ApxyDebugConsoleInteractor: ObservableObject {
    @Published private(set) var state = ApxyDebugConsoleViewState()

    private let store: ApxyDebugStore
    private var updatesTask: Task<Void, Never>?

    init(store: ApxyDebugStore) {
        self.store = store
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
        updateFilterState {
            $0.selectedSessionID = sessionID
        }
    }

    func setSelectedHost(_ host: String?) {
        updateFilterState {
            $0.selectedHost = host
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

    func clear() {
        state.resetVisibleStateForClear()

        Task { [store] in
            await store.clear()
        }
    }

    func resetFilters() {
        applyFilterState(.init())
    }

    func prepareExport() {
        let records = state.records
        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try ApxyDebugConsoleExporter.write(records: records)
                await MainActor.run {
                    self.state.setExportResult(url: url)
                }
            } catch {
                await MainActor.run {
                    self.state.setExportError(error.localizedDescription)
                }
            }
        }
    }

    func dismissExportError() {
        state.exportError = nil
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
        if state.isClearing, snapshot.records.isEmpty {
            state.isClearing = false
        }
    }

    private func refreshDerivedState() {
        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: state.snapshot,
            filterState: state.filterState,
            selectedRecordID: state.selectedRecordID,
            isClearing: state.isClearing
        )

        state.apply(derivedState)
    }

    private func syncSelectedRecord() {
        let derivedState = ApxyDebugConsoleDerivedState.make(
            snapshot: state.snapshot,
            filterState: state.filterState,
            selectedRecordID: state.selectedRecordID,
            isClearing: state.isClearing
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
            guard let self, !self.state.isClearing else { return }
            self.state.highlightedRecordIDs.subtract(insertedIDs)
        }
    }
}

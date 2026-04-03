import Foundation
import Combine
import ApxyCore

@MainActor
public final class ApxyDebugConsoleViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { handleFilterDidChange() }
    }
    @Published var status: ApxyDebugStatusFilter = .all {
        didSet { handleFilterDidChange() }
    }
    @Published var selectedSessionID: String? {
        didSet { handleFilterDidChange() }
    }
    @Published var selectedHost: String? {
        didSet { handleFilterDidChange() }
    }
    @Published var selectedMethod: String? {
        didSet { handleFilterDidChange() }
    }
    @Published var selectedRecordID: String? {
        didSet { syncSelectedRecord() }
    }
    @Published private(set) var snapshot: ApxyDebugSnapshot = .empty
    @Published private(set) var records: [ApxyDebugRecord] = []
    @Published private(set) var sessions: [ApxyDebugSession] = []
    @Published private(set) var totalRecordCount: Int = 0
    @Published private(set) var visibleRecordCount: Int = 0
    @Published private(set) var failureCount: Int = 0
    @Published private(set) var hosts: [String] = []
    @Published private(set) var methods: [String] = []
    @Published private(set) var selectedRecord: ApxyDebugRecord?
    @Published private(set) var exportURL: URL?
    @Published private(set) var exportError: String?

    let store: ApxyDebugStore
    private var updatesTask: Task<Void, Never>?
    private var suppressFilterRefresh = false

    public init(store: ApxyDebugStore) {
        self.store = store
        updatesTask = Task { [weak self, store] in
            let stream = await store.updates()
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                self?.apply(snapshot: snapshot)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var successCount: Int {
        totalRecordCount - failureCount
    }

    var activeFilters: [String] {
        var filters: [String] = []
        if status != .all {
            filters.append(status.title)
        }
        if let selectedSessionID, !selectedSessionID.isEmpty {
            filters.append("Session \(String(selectedSessionID.prefix(8)))")
        }
        if let selectedHost, !selectedHost.isEmpty {
            filters.append(selectedHost)
        }
        if let selectedMethod, !selectedMethod.isEmpty {
            filters.append(selectedMethod)
        }
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            filters.append("\"\(trimmedSearch)\"")
        }
        return filters
    }

    func clear() {
        Task {
            await store.clear()
        }
    }

    func resetFilters() {
        applyFilterChanges {
            searchText = ""
            status = .all
            selectedSessionID = nil
            selectedHost = nil
            selectedMethod = nil
        }
    }

    func prepareExport() {
        let records = self.records
        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try Self.writeExport(records: records)
                await MainActor.run {
                    self.exportURL = url
                    self.exportError = nil
                }
            } catch {
                await MainActor.run {
                    self.exportError = error.localizedDescription
                }
            }
        }
    }

    func dismissExportError() {
        exportError = nil
    }

    private var filter: ApxyDebugConsoleFilter {
        ApxyDebugConsoleFilter(
            searchText: searchText,
            status: status,
            sessionID: selectedSessionID,
            host: selectedHost,
            method: selectedMethod
        )
    }

    private func apply(snapshot: ApxyDebugSnapshot) {
        self.snapshot = snapshot
        refreshDerivedState()
    }

    private static func writeExport(records: [ApxyDebugRecord]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("apxy-debug-\(UUID().uuidString).json")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func refreshDerivedState() {
        sessions = snapshot.sessions
        totalRecordCount = snapshot.records.count
        failureCount = snapshot.records.lazy.filter(\.isFailure).count
        hosts = Array(Set(snapshot.records.lazy.map(\.request.host))).sorted()
        methods = Array(Set(snapshot.records.lazy.map(\.request.method))).sorted()
        records = ApxyDebugFilterEngine.filter(records: snapshot.records, using: filter)
        visibleRecordCount = records.count
        syncSelectedRecord()
    }

    private func syncSelectedRecord() {
        let availableIDs = Set(records.lazy.map(\.id))
        guard !availableIDs.isEmpty else {
            selectedRecordID = nil
            selectedRecord = nil
            return
        }
        if let selectedRecordID, availableIDs.contains(selectedRecordID) {
            selectedRecord = records.first(where: { $0.id == selectedRecordID })
            return
        }
        selectedRecordID = records.first?.id
        selectedRecord = records.first
    }

    private func applyFilterChanges(_ changes: () -> Void) {
        suppressFilterRefresh = true
        changes()
        suppressFilterRefresh = false
        refreshDerivedState()
    }

    private func handleFilterDidChange() {
        guard !suppressFilterRefresh else { return }
        refreshDerivedState()
    }
}

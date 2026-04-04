import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
extension ApxyDebugConsoleView {
    var compactBody: some View {
        NavigationStack(path: screenModel.compactPathBinding) {
            consoleList(selection: nil)
                .navigationTitle("APXY UI")
                .apxyInlineTitle()
                .navigationDestination(for: ApxyDebugConsoleRoute.self) { route in
                    if let record = screenModel.record(for: route) {
                        ApxyDebugRecordDetailView(record: record)
                    } else {
                        placeholderDetail
                    }
                }
        }
    }

    var regularBody: some View {
        NavigationSplitView {
            consoleList(selection: regularSelection)
                .navigationTitle("APXY UI")
                .apxyInlineTitle()
        } detail: {
            NavigationStack {
                if let record = screenModel.selectedRecord {
                    ApxyDebugRecordDetailView(record: record)
                } else {
                    placeholderDetail
                }
            }
        }
    }

    func consoleList(selection: Binding<String?>?) -> some View {
        ApxyDebugConsoleListView(
            records: screenModel.records,
            totalRecordCount: screenModel.totalRecordCount,
            visibleRecordCount: screenModel.visibleRecordCount,
            failureCount: screenModel.failureCount,
            searchText: screenModel.viewModel.searchText,
            activeFilters: screenModel.activeFilters,
            highlightedRecordIDs: screenModel.highlightedRecordIDs,
            usesCompactNavigation: usesCompactNavigation,
            selection: selection,
            selectedStatus: screenModel.statusBinding,
            onResetFilters: screenModel.resetFilters,
            onSelectRecord: handleRecordSelection,
            quickActions: quickActions(for:)
        )
        .searchable(text: screenModel.searchTextBinding, placement: .toolbar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ApxyDebugConsoleFiltersMenu(
                    selectedSessionID: screenModel.selectedSessionIDBinding,
                    selectedHost: screenModel.selectedHostBinding,
                    selectedMethod: screenModel.selectedMethodBinding,
                    sessions: screenModel.sessions,
                    hosts: screenModel.hosts,
                    methods: screenModel.methods,
                    onReset: screenModel.resetFilters
                )
                ApxyDebugConsoleExportMenu(
                    exportURL: screenModel.exportURL,
                    onPrepareExport: screenModel.prepareExport
                )
                Button("Clear", systemImage: "trash", role: .destructive) {
                    isShowingClearConfirmation = true
                }
            }
        }
    }

    var regularSelection: Binding<String?> {
        screenModel.regularSelectionBinding
    }

    var placeholderDetail: some View {
        ApxyDebugPlaceholderPanel(
            title: "Select a request",
            systemImage: "point.3.connected.trianglepath.dotted",
            message: "Choose a request to inspect the URL, headers, cookies, body, timing, and a cURL preview."
        )
        .padding()
    }
}

import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
public struct ApxyDebugConsoleView: View {
    @StateObject private var viewModel: ApxyDebugConsoleViewModel

    public init(store: ApxyDebugStore) {
        _viewModel = StateObject(wrappedValue: ApxyDebugConsoleViewModel(store: store))
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedRecordID) {
                Section {
                    ApxyDebugConsoleSummaryBar(
                        totalCount: viewModel.totalRecordCount,
                        failureCount: viewModel.failureCount,
                        selectedStatus: $viewModel.status
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)

                if !viewModel.activeFilters.isEmpty {
                    Section {
                        activeFiltersView
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if viewModel.records.isEmpty {
                    Section {
                        emptyState
                    }
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(viewModel.records) { record in
                            ApxyDebugRecordRow(record: record)
                                .tag(record.id)
                                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 16))
                        }
                    } header: {
                        sidebarHeader
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 8)
            .listStyle(.plain)
            .navigationTitle("UI Debug")
            .searchable(text: $viewModel.searchText, placement: .toolbar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    filtersMenu
                    exportMenu
                    Button(role: .destructive, action: viewModel.clear) {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        } detail: {
            if let record = viewModel.selectedRecord {
                ApxyDebugRecordDetailView(record: record)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 44))
                    Text("Select a request")
                        .font(.headline)
                    Text("Choose a row to inspect headers, payloads, and timing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .padding()
            }
        }
        .alert("Export Failed", isPresented: Binding(get: {
            viewModel.exportError != nil
        }, set: { newValue in
            if !newValue {
                viewModel.dismissExportError()
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportError ?? "")
        }
    }

    private var sidebarHeader: some View {
        HStack {
            Text(sidebarHeaderText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            if viewModel.visibleRecordCount != viewModel.totalRecordCount {
                Button("Reset") {
                    viewModel.resetFilters()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
            }
        }
        .textCase(nil)
    }

    private var activeFiltersView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Filters")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.activeFilters, id: \.self) { filter in
                        Text(filter)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Button("Reset Filters") {
                        viewModel.resetFilters()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No captured requests")
                .font(.headline)
            Text("Start using the app and network traffic will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var sidebarHeaderText: String {
        if viewModel.visibleRecordCount == viewModel.totalRecordCount {
            return "\(viewModel.visibleRecordCount) request\(viewModel.visibleRecordCount == 1 ? "" : "s")"
        }
        return "\(viewModel.visibleRecordCount) of \(viewModel.totalRecordCount) requests"
    }

    private var filtersMenu: some View {
        Menu {
            Picker("Session", selection: $viewModel.selectedSessionID) {
                Text("All Sessions").tag(String?.none)
                ForEach(viewModel.sessions) { session in
                    Text(ApxyDebugValueFormatters.sessionTitle(session)).tag(Optional(session.id))
                }
            }
            Picker("Host", selection: $viewModel.selectedHost) {
                Text("All Hosts").tag(String?.none)
                ForEach(viewModel.hosts, id: \.self) { host in
                    Text(host).tag(Optional(host))
                }
            }
            Picker("Method", selection: $viewModel.selectedMethod) {
                Text("All Methods").tag(String?.none)
                ForEach(viewModel.methods, id: \.self) { method in
                    Text(method).tag(Optional(method))
                }
            }
            Divider()
            Button("Reset Filters", action: viewModel.resetFilters)
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder
    private var exportMenu: some View {
        Menu {
            Button("Prepare JSON Export", action: viewModel.prepareExport)
            if let exportURL = viewModel.exportURL {
                ShareLink(item: exportURL) {
                    Label("Share Latest Export", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ApxyDebugConsoleContainer: View {
    public init() {}

    public var body: some View {
        if let store = Apxy.activeDebugStore {
            ApxyDebugConsoleView(store: store)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "ladybug")
                    .font(.system(size: 36))
                Text("UI Debug Disabled")
                    .font(.headline)
                Text("Enable `debugConsole` in `ApxyOptions` before presenting this screen.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

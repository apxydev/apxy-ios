import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleListView<QuickActions: View>: View {
    let records: [ApxyDebugRecord]
    let totalRecordCount: Int
    let visibleRecordCount: Int
    let failureCount: Int
    let searchText: String
    let activeFilters: [String]
    let highlightedRecordIDs: Set<String>
    let usesCompactNavigation: Bool
    let selection: Binding<String?>?
    @Binding var selectedStatus: ApxyDebugStatusFilter
    let onResetFilters: () -> Void
    let onSelectRecord: (ApxyDebugRecord) -> Void
    let quickActions: (ApxyDebugRecord) -> QuickActions

    var body: some View {
        List(selection: selection) {
            Section {
                ApxyDebugConsoleSummaryBar(
                    totalCount: totalRecordCount,
                    failureCount: failureCount,
                    selectedStatus: $selectedStatus
                )
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
            .listRowSeparator(.hidden)

            if records.isEmpty {
                Section {
                    emptyState
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(records) { record in
                        recordRow(for: record)
                    }
                } header: {
                    sidebarHeader
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 8)
        .listStyle(.plain)
    }

    private func recordRow(for record: ApxyDebugRecord) -> some View {
        Group {
            if usesCompactNavigation {
                Button {
                    onSelectRecord(record)
                } label: {
                    rowLabel(for: record)
                }
                .buttonStyle(.plain)
            } else {
                rowLabel(for: record)
                    .tag(record.id)
            }
        }
        .contextMenu {
            quickActions(record)
        }
        .modifier(ApxyDebugRecordSwipeActionsModifier(record: record))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private func rowLabel(for record: ApxyDebugRecord) -> some View {
        ApxyDebugRecordRow(
            record: record,
            isHighlighted: highlightedRecordIDs.contains(record.id)
        )
    }

    private var sidebarHeader: some View {
        HStack {
            Text(sidebarHeaderText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            if !activeFilters.isEmpty {
                Button("Reset", action: onResetFilters)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.background)
        .textCase(nil)
    }

    private var sidebarHeaderText: String {
        if activeFilters.isEmpty {
            return "Requests"
        }
        return "\(visibleRecordCount) of \(totalRecordCount)"
    }

    private var emptyState: some View {
        Group {
            if #available(iOS 17.0, macOS 14.0, *) {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   activeFilters.isEmpty {
                    ContentUnavailableView(
                        "No Captured Requests",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("Start using the app and Apxy will list new requests here.")
                    )
                } else {
                    ContentUnavailableView.search
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No matching requests")
                        .font(.headline)
                    Text("Try adjusting the search or resetting filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
private struct ApxyDebugConsoleListViewPreview: View {
    @State private var selectedStatus: ApxyDebugStatusFilter = .all
    @State private var selectedRecordID: String? = ApxyDebugPreviewFixtures.records.first?.id

    var body: some View {
        NavigationStack {
            ApxyDebugConsoleListView(
                records: ApxyDebugPreviewFixtures.records,
                totalRecordCount: ApxyDebugPreviewFixtures.records.count,
                visibleRecordCount: ApxyDebugPreviewFixtures.records.count,
                failureCount: ApxyDebugPreviewFixtures.records.filter(\.isFailure).count,
                searchText: "",
                activeFilters: [],
                highlightedRecordIDs: [ApxyDebugPreviewFixtures.failedRecord.id],
                usesCompactNavigation: false,
                selection: $selectedRecordID,
                selectedStatus: $selectedStatus,
                onResetFilters: {},
                onSelectRecord: { record in
                    selectedRecordID = record.id
                },
                quickActions: { _ in
                    EmptyView()
                }
            )
            .navigationTitle("APXY UI")
        }
        .frame(minWidth: 420, minHeight: 520)
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console List") {
    ApxyDebugConsoleListViewPreview()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console List Empty") {
    ApxyDebugConsoleListView(
        records: [],
        totalRecordCount: ApxyDebugPreviewFixtures.records.count,
        visibleRecordCount: 0,
        failureCount: 1,
        searchText: "timeout",
        activeFilters: ApxyDebugPreviewFixtures.activeFilters,
        highlightedRecordIDs: [],
        usesCompactNavigation: true,
        selection: nil,
        selectedStatus: .constant(.failures),
        onResetFilters: {},
        onSelectRecord: { _ in },
        quickActions: { _ in
            EmptyView()
        }
    )
    .frame(minWidth: 420, minHeight: 320)
}
#endif

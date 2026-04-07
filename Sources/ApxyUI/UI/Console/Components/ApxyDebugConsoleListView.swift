import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleListView<QuickActions: View>: View {
    let records: [ApxyDebugRecord]
    let totalRecordCount: Int
    let visibleRecordCount: Int
    let searchText: String
    let activeFilters: [String]
    let highlightedRecordIDs: Set<String>
    let usesCompactNavigation: Bool
    let selection: Binding<String?>?
    let onResetFilters: () -> Void
    let onSelectRecord: (ApxyDebugRecord) -> Void
    let quickActions: (ApxyDebugRecord) -> QuickActions
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        List(selection: selection) {
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
        .padding(.top, 8)
        .scrollContentBackground(.hidden)
        .background(theme.canvas.ignoresSafeArea())
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
        .listRowBackground(Color.clear)
    }

    private func rowLabel(for record: ApxyDebugRecord) -> some View {
        ApxyDebugRecordRow(
            record: record,
            isHighlighted: highlightedRecordIDs.contains(record.id)
        )
    }

    private var sidebarHeader: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        return HStack {
            Text(sidebarHeaderText)
                .font(.subheadline.bold())
                .foregroundStyle(theme.textSecondary)
            Spacer()
            if !activeFilters.isEmpty {
                Button("Reset", action: onResetFilters)
                    .buttonStyle(.plain)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .textCase(nil)
    }

    private var sidebarHeaderText: String {
        if activeFilters.isEmpty {
            return "Requests"
        }
        return "\(visibleRecordCount) of \(totalRecordCount) shown"
    }

    private var emptyState: some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           activeFilters.isEmpty {
            ApxyDebugPlaceholderPanel(
                title: "No Captured Requests",
                systemImage: "point.3.connected.trianglepath.dotted",
                message: "Start using the app and Apxy will list new requests here."
            )
        } else {
            ApxyDebugPlaceholderPanel(
                title: "No Matching Requests",
                systemImage: "line.3.horizontal.decrease.circle",
                message: "Try adjusting the search or resetting filters."
            )
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
private struct ApxyDebugConsoleListViewPreview: View {
    @State private var selectedRecordID: String? = ApxyDebugPreviewFixtures.records.first?.id

    var body: some View {
        NavigationStack {
            ApxyDebugConsoleListView(
                records: ApxyDebugPreviewFixtures.records,
                totalRecordCount: ApxyDebugPreviewFixtures.records.count,
                visibleRecordCount: ApxyDebugPreviewFixtures.records.count,
                searchText: "",
                activeFilters: [],
                highlightedRecordIDs: [ApxyDebugPreviewFixtures.failedRecord.id],
                usesCompactNavigation: false,
                selection: $selectedRecordID,
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
#Preview("Console List iOS") {
    ApxyDebugConsoleListViewPreview()
        .apxyPreviewList(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console List macOS") {
    ApxyDebugConsoleListViewPreview()
        .apxyPreviewList(.macOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console List Empty iOS") {
    ApxyDebugConsoleListView(
        records: [],
        totalRecordCount: ApxyDebugPreviewFixtures.records.count,
        visibleRecordCount: 0,
        searchText: "timeout",
        activeFilters: ApxyDebugPreviewFixtures.activeFilters,
        highlightedRecordIDs: [],
        usesCompactNavigation: true,
        selection: nil,
        onResetFilters: {},
        onSelectRecord: { _ in },
        quickActions: { _ in
            EmptyView()
        }
    )
    .apxyPreviewCompactScreen(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console List Empty macOS") {
    ApxyDebugConsoleListView(
        records: [],
        totalRecordCount: ApxyDebugPreviewFixtures.records.count,
        visibleRecordCount: 0,
        searchText: "timeout",
        activeFilters: ApxyDebugPreviewFixtures.activeFilters,
        highlightedRecordIDs: [],
        usesCompactNavigation: true,
        selection: nil,
        onResetFilters: {},
        onSelectRecord: { _ in },
        quickActions: { _ in
            EmptyView()
        }
    )
    .apxyPreviewCompactScreen(.macOS)
}
#endif

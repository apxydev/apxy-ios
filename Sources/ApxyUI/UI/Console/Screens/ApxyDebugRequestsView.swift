import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRequestsView: View {
    @StateObject private var screenModel: ApxyDebugConsoleScreenModel
    private let ownsCompactNavigationStack: Bool
    @Environment(\.colorScheme) private var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    init(
        store: ApxyDebugStore,
        scope: ApxyDebugConsoleScope,
        ownsCompactNavigationStack: Bool = true
    ) {
        self.ownsCompactNavigationStack = ownsCompactNavigationStack
        _screenModel = StateObject(wrappedValue: ApxyDebugConsoleScreenModel(store: store, scope: scope))
    }

    var body: some View {
        Group {
            if usesCompactNavigation {
                compactBody
            } else {
                regularBody
            }
        }
        .onAppear {
            screenModel.reconcileNavigation(usesCompactNavigation: usesCompactNavigation)
        }
        .onChange(of: screenModel.records.map(\.id)) { _ in
            screenModel.reconcileNavigation(usesCompactNavigation: usesCompactNavigation)
        }
        .onChange(of: screenModel.selectedRecordID) { _ in
            screenModel.syncRegularSelectionIfNeeded(usesCompactNavigation: usesCompactNavigation)
        }
        .background(theme.canvas.ignoresSafeArea())
        .tint(theme.accent)
        .apxyNavigationChrome(theme: theme, colorScheme: colorScheme)
    }

    @ViewBuilder
    var compactBody: some View {
        if ownsCompactNavigationStack {
            NavigationStack(path: screenModel.compactPathBinding) {
                ownedCompactContent
            }
        } else {
            embeddedCompactContent
        }
    }

    // Path-based navigation: used when this view owns its NavigationStack.
    var ownedCompactContent: some View {
        consoleList(selection: nil)
            .navigationTitle(screenModel.navigationTitle)
            .apxyInlineTitle()
            .navigationDestination(for: ApxyDebugRoute.self) { route in
                if let record = screenModel.record(for: route) {
                    ApxyDebugRecordDetailView(record: record)
                } else {
                    placeholderDetail
                }
            }
            .navigationDestination(for: ApxyDebugInspectorRoute.self) { destination in
                if let record = screenModel.compactSelectedRecord {
                    ApxyDebugInspectorRouteView(destination: destination, record: record)
                }
            }
            .background(theme.canvas.ignoresSafeArea())
    }

    // Boolean-based navigation: used when embedded inside another NavigationStack (e.g. sessions tab).
    var embeddedCompactContent: some View {
        consoleList(selection: nil)
            .navigationTitle(screenModel.navigationTitle)
            .apxyInlineTitle()
            .navigationDestination(isPresented: screenModel.compactDetailPresentedBinding) {
                if let record = screenModel.compactSelectedRecord {
                    ApxyDebugRecordDetailView(record: record)
                        .navigationDestination(for: ApxyDebugInspectorRoute.self) { destination in
                            ApxyDebugInspectorRouteView(destination: destination, record: record)
                        }
                } else {
                    placeholderDetail
                }
            }
            .background(theme.canvas.ignoresSafeArea())
    }

    var regularBody: some View {
        NavigationSplitView {
            consoleList(selection: regularSelection)
                .navigationTitle(screenModel.navigationTitle)
                .apxyInlineTitle()
        } detail: {
            NavigationStack(path: screenModel.inspectorPathBinding) {
                Group {
                    if let record = screenModel.selectedRecord {
                        ApxyDebugRecordDetailView(record: record)
                    } else {
                        placeholderDetail
                    }
                }
                .navigationDestination(for: ApxyDebugInspectorRoute.self) { destination in
                    if let record = screenModel.selectedRecord {
                        ApxyDebugInspectorRouteView(destination: destination, record: record)
                    }
                }
            }
        }
        .background(theme.canvas.ignoresSafeArea())
    }

    func consoleList(selection: Binding<String?>?) -> some View {
        ApxyDebugConsoleListView(
            records: screenModel.records,
            totalRecordCount: screenModel.totalRecordCount,
            visibleRecordCount: screenModel.visibleRecordCount,
            searchText: screenModel.viewModel.searchText,
            activeFilters: screenModel.activeFilters,
            highlightedRecordIDs: screenModel.highlightedRecordIDs,
            usesCompactNavigation: usesCompactNavigation,
            selection: selection,
            onResetFilters: screenModel.resetFilters,
            onSelectRecord: handleRecordSelection,
            quickActions: quickActions(for:)
        )
        .searchable(text: screenModel.searchTextBinding, placement: .toolbar)
        .toolbar {
#if os(iOS)
            ToolbarItemGroup(placement: .topBarTrailing) {
                trailingToolbarContent
            }
#else
            ToolbarItemGroup(placement: .primaryAction) {
                trailingToolbarContent
            }
#endif
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
        .background(theme.canvas.ignoresSafeArea())
    }

    var theme: ApxyDebugThemePalette {
        ApxyDebugTheme.palette(for: colorScheme)
    }

    @ViewBuilder
    var trailingToolbarContent: some View {
        ApxyDebugConsoleFiltersMenu(
            selectedSessionID: screenModel.showsSessionFilter
                ? screenModel.selectedSessionIDBinding
                : nil,
            selectedStatus: screenModel.statusBinding,
            selectedMethod: screenModel.selectedMethodBinding,
            sessions: screenModel.sessions,
            methods: screenModel.methods,
            onReset: screenModel.resetFilters
        )
    }

    @ViewBuilder
    func quickActions(for record: ApxyDebugRecord) -> some View {
        Button("Copy URL", systemImage: "link") {
            ApxyDebugClipboard.copy(record.request.currentURL ?? record.request.url)
        }

        Button("Copy cURL", systemImage: "terminal") {
            ApxyDebugClipboard.copy(
                ApxyDebugCurlFormatter.makeCurl(
                    for: record,
                    useCurrentRequest: record.request.currentURL != nil || !record.request.currentHeaders.isEmpty
                )
            )
        }

        if let body = ApxyDebugBodyFormatter.displayText(
            data: record.response?.body,
            contentType: record.response?.contentType
        ) {
            Button("Copy Response Body", systemImage: "doc.on.doc") {
                ApxyDebugClipboard.copy(body)
            }
        }
    }

    func handleRecordSelection(_ record: ApxyDebugRecord) {
        screenModel.selectRecord(record, usesCompactNavigation: usesCompactNavigation)
    }

    var usesCompactNavigation: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Requests Screen Live iOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugRequestsView(store: store, scope: .activeSession)
    }
    .apxyPreviewScreen(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Requests Screen Session macOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugRequestsView(store: store, scope: .session("session-beta"))
    }
    .apxyPreviewScreen(.macOS)
}
#endif

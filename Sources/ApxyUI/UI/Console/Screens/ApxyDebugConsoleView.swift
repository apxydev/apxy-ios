import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
public struct ApxyDebugConsoleView: View {
    private let store: ApxyDebugStore
    @State private var selectedTab: Tab = .liveTraffic
    @StateObject private var settingsViewModel: ApxyDebugRuntimeSettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    private enum Tab: Hashable {
        case liveTraffic
        case sessions
        case settings
    }

    public init(store: ApxyDebugStore) {
        self.store = store
        _settingsViewModel = StateObject(wrappedValue: ApxyDebugRuntimeSettingsViewModel(debugStore: store))
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            ApxyDebugRequestsView(store: store, scope: .activeSession)
                .tabItem {
                    Label("Live Traffic", systemImage: "bolt.horizontal.circle")
                }
                .tag(Tab.liveTraffic)

            ApxyDebugSessionsView(store: store)
                .tabItem {
                    Label("Sessions", systemImage: "square.stack.3d.up")
                }
                .tag(Tab.sessions)

            NavigationStack {
                ApxyDebugRuntimeSettingsView(viewModel: settingsViewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .background(theme.canvas.ignoresSafeArea())
        .tint(theme.accent)
        .apxyVisibleNavigationBar()
    }

    var theme: ApxyDebugThemePalette {
        ApxyDebugTheme.palette(for: colorScheme)
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ApxyDebugConsoleContainer: View {
    public init() {}

    public var body: some View {
        if let store = Apxy.activeDebugStore {
            ApxyDebugConsoleView(store: store)
        } else {
            ApxyDebugPlaceholderPanel(
                title: "UI Debug Disabled",
                systemImage: "ladybug",
                message: "Enable `debugConsole` in `ApxyOptions` before presenting this screen."
            )
            .padding()
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Console Screen Light iOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugConsoleView(store: store)
    }
    .apxyPreviewScreen(.iOS)
    .preferredColorScheme(.light)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console Screen Dark macOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugConsoleView(store: store)
    }
    .apxyPreviewScreen(.macOS)
    .preferredColorScheme(.dark)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console Container Disabled iOS") {
    NavigationStack {
        ApxyDebugConsoleContainer()
    }
    .apxyPreviewCompactScreen(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console Container Disabled macOS") {
    NavigationStack {
        ApxyDebugConsoleContainer()
    }
    .apxyPreviewCompactScreen(.macOS)
}
#endif

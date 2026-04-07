import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugSessionsView: View {
    private let store: ApxyDebugStore
    @StateObject private var viewModel: ApxyDebugConsoleViewModel
    @State private var navigationPath: [String] = []
    @Environment(\.colorScheme) private var colorScheme

    init(store: ApxyDebugStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: ApxyDebugConsoleViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if viewModel.sessions.isEmpty {
                    Section {
                        ApxyDebugPlaceholderPanel(
                            title: "No Sessions Yet",
                            systemImage: "square.stack.3d.up.slash",
                            message: "Start using the app and APXY will group captured traffic into sessions here."
                        )
                    }
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                            Button {
                                navigationPath.append(session.id)
                            } label: {
                                ApxyDebugSessionRow(
                                    session: session,
                                    isActive: index == 0
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                sessionQuickActions(session: session, isActive: index == 0)
                            }
                            .modifier(ApxyDebugSessionSwipeActionsModifier(
                                session: session,
                                isActive: index == 0,
                                onShare: { viewModel.shareSession(id: $0) },
                                onDelete: { viewModel.deleteSession(id: $0) }
                            ))
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .apxyInlineTitle()
            .environment(\.defaultMinListRowHeight, 8)
            .listStyle(.plain)
            .padding(.top, 8)
            .scrollContentBackground(.hidden)
            .background(theme.canvas.ignoresSafeArea())
            .navigationDestination(for: String.self) { sessionID in
                ApxyDebugRequestsView(
                    store: store,
                    scope: .session(sessionID),
                    ownsCompactNavigationStack: false
                )
            }
        }
        .background(theme.canvas.ignoresSafeArea())
        .tint(theme.accent)
        .apxyNavigationChrome(theme: theme, colorScheme: colorScheme)
        .alert("Share Failed", isPresented: Binding(
            get: { viewModel.shareError != nil },
            set: { if !$0 { viewModel.shareError = nil } }
        )) {
            Button("OK") { viewModel.shareError = nil }
        } message: {
            Text(viewModel.shareError ?? "")
        }
    }

    @ViewBuilder
    private func sessionQuickActions(session: ApxyDebugSession, isActive: Bool) -> some View {
        Button {
            viewModel.shareSession(id: session.id)
        } label: {
            Label("Share to Server", systemImage: "arrow.up.circle")
        }
        .disabled(!session.isShareable)

        Divider()

        if !isActive {
            Button(role: .destructive) {
                viewModel.deleteSession(id: session.id)
            } label: {
                Label("Delete Session", systemImage: "trash")
            }
        }
    }

    private var theme: ApxyDebugThemePalette {
        ApxyDebugTheme.palette(for: colorScheme)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Sessions Screen iOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugSessionsView(store: store)
    }
    .apxyPreviewScreen(.iOS)
}
#endif

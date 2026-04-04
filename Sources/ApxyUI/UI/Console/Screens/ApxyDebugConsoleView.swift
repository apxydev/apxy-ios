import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
public struct ApxyDebugConsoleView: View {
    @StateObject var screenModel: ApxyDebugConsoleScreenModel
    @State var isShowingClearConfirmation = false
#if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif

    public init(store: ApxyDebugStore) {
        _screenModel = StateObject(wrappedValue: ApxyDebugConsoleScreenModel(store: store))
    }

    public var body: some View {
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
        .onChange(of: screenModel.compactPath) { _ in
            screenModel.syncCompactSelectionIfNeeded(usesCompactNavigation: usesCompactNavigation)
        }
        .alert("Export Failed", isPresented: Binding(get: {
            screenModel.exportError != nil
        }, set: { newValue in
            if !newValue {
                screenModel.dismissExportError()
            }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(screenModel.exportError ?? "")
        }
        .confirmationDialog(
            "Clear all captured requests?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Requests", role: .destructive) {
                screenModel.clearRecords()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every captured request from the local Apxy console.")
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
#Preview("Console Screen iOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugConsoleView(store: store)
    }
    .apxyPreviewScreen(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Console Screen macOS") {
    ApxyDebugPreviewStoreContainer { store in
        ApxyDebugConsoleView(store: store)
    }
    .apxyPreviewScreen(.macOS)
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

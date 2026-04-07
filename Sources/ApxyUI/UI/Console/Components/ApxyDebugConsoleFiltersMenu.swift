import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleFiltersMenu: View {
    var selectedSessionID: Binding<String?>?
    @Binding var selectedStatus: ApxyDebugStatusFilter
    @Binding var selectedMethod: String?
    let sessions: [ApxyDebugSession]
    let methods: [String]
    let onReset: () -> Void

    var body: some View {
        Menu {
            if let selectedSessionID {
                Picker("Session", selection: selectedSessionID) {
                    Text("All Sessions").tag(String?.none)
                    ForEach(sessions) { session in
                        Text(ApxyDebugValueFormatters.sessionTitle(session)).tag(Optional(session.id))
                    }
                }
            }
            Picker("Status", selection: $selectedStatus) {
                ForEach(ApxyDebugStatusFilter.allCases, id: \.self) { status in
                    Text(status.title).tag(status)
                }
            }
            Picker("Method", selection: $selectedMethod) {
                Text("All Methods").tag(String?.none)
                ForEach(methods, id: \.self) { method in
                    Text(method).tag(Optional(method))
                }
            }
            Divider()
            Button("Reset Filters", action: onReset)
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
private struct ApxyDebugConsoleFiltersMenuPreview: View {
    @State private var selectedSessionID: String? = ApxyDebugPreviewFixtures.sessions.last?.id
    @State private var selectedStatus: ApxyDebugStatusFilter = .failures
    @State private var selectedMethod: String? = "PATCH"

    var body: some View {
        ApxyDebugConsoleFiltersMenu(
            selectedSessionID: $selectedSessionID,
            selectedStatus: $selectedStatus,
            selectedMethod: $selectedMethod,
            sessions: ApxyDebugPreviewFixtures.sessions,
            methods: ["GET", "POST", "PATCH", "DELETE"],
            onReset: {
                selectedSessionID = nil
                selectedStatus = .all
                selectedMethod = nil
            }
        )
        .padding()
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Filters Menu iOS") {
    ApxyDebugConsoleFiltersMenuPreview()
        .apxyPreviewControl(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Filters Menu macOS") {
    ApxyDebugConsoleFiltersMenuPreview()
        .apxyPreviewControl(.macOS)
}
#endif

import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleFiltersMenu: View {
    @Binding var selectedSessionID: String?
    @Binding var selectedHost: String?
    @Binding var selectedMethod: String?
    let sessions: [ApxyDebugSession]
    let hosts: [String]
    let methods: [String]
    let onReset: () -> Void

    var body: some View {
        Menu {
            Picker("Session", selection: $selectedSessionID) {
                Text("All Sessions").tag(String?.none)
                ForEach(sessions) { session in
                    Text(ApxyDebugValueFormatters.sessionTitle(session)).tag(Optional(session.id))
                }
            }
            Picker("Host", selection: $selectedHost) {
                Text("All Hosts").tag(String?.none)
                ForEach(hosts, id: \.self) { host in
                    Text(host).tag(Optional(host))
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
    @State private var selectedHost: String? = "edge.apxy.dev"
    @State private var selectedMethod: String? = "PATCH"

    var body: some View {
        ApxyDebugConsoleFiltersMenu(
            selectedSessionID: $selectedSessionID,
            selectedHost: $selectedHost,
            selectedMethod: $selectedMethod,
            sessions: ApxyDebugPreviewFixtures.sessions,
            hosts: ["api.apxy.dev", "auth.apxy.dev", "edge.apxy.dev", "mock.apxy.dev"],
            methods: ["GET", "POST", "PATCH", "DELETE"],
            onReset: {
                selectedSessionID = nil
                selectedHost = nil
                selectedMethod = nil
            }
        )
        .padding()
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Filters Menu") {
    ApxyDebugConsoleFiltersMenuPreview()
}
#endif

import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugTextDetailView: View {
    let title: String
    let text: String
    let emptyMessage: String

    var body: some View {
        Group {
            if text.isEmpty {
                emptyContent
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            if !text.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy", systemImage: "doc.on.doc") {
                        ApxyDebugClipboard.copy(text)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            ContentUnavailableView(emptyMessage, systemImage: "doc.text")
        } else {
            List {
                Section {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Text Detail") {
    NavigationStack {
        ApxyDebugTextDetailView(
            title: "Response Headers",
            text: """
            Content-Type: application/json
            X-Request-ID: req-success
            X-Preview: true
            """,
            emptyMessage: "No text available"
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Text Detail Empty") {
    NavigationStack {
        ApxyDebugTextDetailView(
            title: "Error Details",
            text: "",
            emptyMessage: "No error details were captured."
        )
    }
}
#endif

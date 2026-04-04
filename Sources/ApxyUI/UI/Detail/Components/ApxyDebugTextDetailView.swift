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
                List {
                    Section {
                        ScrollView([.vertical, .horizontal]) {
                            Text(text)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .modifier(ApxyDebugDetailListStyleModifier())
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
            ApxyDebugPlaceholderPanel(title: title, systemImage: "doc.text", message: emptyMessage)
                .padding()
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Text Detail iOS") {
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
    .apxyPreviewDetail(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Text Detail macOS") {
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
    .apxyPreviewDetail(.macOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Text Detail Empty iOS") {
    NavigationStack {
        ApxyDebugTextDetailView(
            title: "Error Details",
            text: "",
            emptyMessage: "No error details were captured."
        )
    }
    .apxyPreviewDetail(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Text Detail Empty macOS") {
    NavigationStack {
        ApxyDebugTextDetailView(
            title: "Error Details",
            text: "",
            emptyMessage: "No error details were captured."
        )
    }
    .apxyPreviewDetail(.macOS)
}
#endif

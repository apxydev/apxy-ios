import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugTextDetailView: View {
    let title: String
    let text: String
    let emptyMessage: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if text.isEmpty {
                emptyContent
            } else {
                List {
                    Section {
                        codeBlock
                    }
                    .listRowBackground(Color.clear)
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

    private var codeBlock: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        return ApxyDebugSurfaceCard(style: .terminal) {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(theme.terminalBar)
                    .frame(height: 10)
                    .padding(.bottom, 12)

                ScrollView([.vertical, .horizontal]) {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        ApxyDebugPlaceholderPanel(title: title, systemImage: "doc.text", message: emptyMessage)
            .padding()
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

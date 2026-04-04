import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugBodyDetailView: View {
    let title: String
    let contentType: String?
    let size: Int64?
    let presentation: ApxyDebugBodyFormatter.Presentation
    let quickCopyTitle: String?
    let onQuickCopy: (() -> Void)?

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Content Type") {
                    Text(contentType ?? "Unknown")
                }
                LabeledContent("Size") {
                    Text(ApxyDebugValueFormatters.bytes(size))
                }
                if let quickCopyTitle, let onQuickCopy, allowsQuickCopy {
                    Button(quickCopyTitle, action: onQuickCopy)
                }
            }

            Section(title) {
                bodyContent
            }
        }
        .navigationTitle(title)
        .modifier(ApxyDebugDetailListStyleModifier())
        .toolbar {
            if let onQuickCopy, allowsQuickCopy {
                ToolbarItem(placement: .primaryAction) {
                    Button(quickCopyTitle ?? "Copy", systemImage: "doc.on.doc", action: onQuickCopy)
                }
            }
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch presentation {
        case .empty:
            placeholder(icon: "nosign", title: "Empty Body", message: "This request completed without a body payload.")
        case .unavailable:
            placeholder(icon: "exclamationmark.circle", title: "Unavailable", message: "The body size was recorded, but the payload itself is not available.")
        case let .text(text):
            ScrollView([.vertical, .horizontal]) {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
        case let .binary(summary):
            placeholder(icon: "doc.fill", title: "Binary Body", message: "\(summary) of binary data was captured. Text preview is unavailable.")
        }
    }

    private var allowsQuickCopy: Bool {
        switch presentation {
        case .text:
            return true
        case .empty, .unavailable, .binary:
            return false
        }
    }

    private func placeholder(icon: String, title: String, message: String) -> some View {
        ApxyDebugPlaceholderPanel(title: title, systemImage: icon, message: message)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Body Detail Text iOS") {
    NavigationStack {
        ApxyDebugBodyDetailView(
            title: "Response Body",
            contentType: "application/json",
            size: Int64(ApxyDebugPreviewFixtures.successRecord.response?.body?.count ?? 0),
            presentation: ApxyDebugBodyFormatter.presentation(
                data: ApxyDebugPreviewFixtures.successRecord.response?.body,
                contentType: ApxyDebugPreviewFixtures.successRecord.response?.contentType,
                bodySize: ApxyDebugPreviewFixtures.successRecord.response?.bodySize
            ),
            quickCopyTitle: "Copy JSON",
            onQuickCopy: {}
        )
    }
    .apxyPreviewDetail(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Body Detail Text macOS") {
    NavigationStack {
        ApxyDebugBodyDetailView(
            title: "Response Body",
            contentType: "application/json",
            size: Int64(ApxyDebugPreviewFixtures.successRecord.response?.body?.count ?? 0),
            presentation: ApxyDebugBodyFormatter.presentation(
                data: ApxyDebugPreviewFixtures.successRecord.response?.body,
                contentType: ApxyDebugPreviewFixtures.successRecord.response?.contentType,
                bodySize: ApxyDebugPreviewFixtures.successRecord.response?.bodySize
            ),
            quickCopyTitle: "Copy JSON",
            onQuickCopy: {}
        )
    }
    .apxyPreviewDetail(.macOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Body Detail Binary Placeholder iOS") {
    NavigationStack {
        ApxyDebugBodyDetailView(
            title: "Request Body",
            contentType: "application/octet-stream",
            size: 2048,
            presentation: .binary(summary: "2 KB"),
            quickCopyTitle: nil,
            onQuickCopy: nil
        )
    }
    .apxyPreviewDetail(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Body Detail Binary Placeholder macOS") {
    NavigationStack {
        ApxyDebugBodyDetailView(
            title: "Request Body",
            contentType: "application/octet-stream",
            size: 2048,
            presentation: .binary(summary: "2 KB"),
            quickCopyTitle: nil,
            onQuickCopy: nil
        )
    }
    .apxyPreviewDetail(.macOS)
}
#endif

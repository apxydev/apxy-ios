import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
extension ApxyDebugConsoleView {
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

extension View {
    @ViewBuilder
    func apxyInlineTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}

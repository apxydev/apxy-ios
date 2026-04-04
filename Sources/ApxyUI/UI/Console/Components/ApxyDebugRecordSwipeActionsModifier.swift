import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordSwipeActionsModifier: ViewModifier {
    let record: ApxyDebugRecord

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    ApxyDebugClipboard.copy(
                        ApxyDebugCurlFormatter.makeCurl(
                            for: record,
                            useCurrentRequest: record.request.currentURL != nil || !record.request.currentHeaders.isEmpty
                        )
                    )
                } label: {
                    Label("cURL", systemImage: "terminal")
                }
                .tint(.indigo)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    ApxyDebugClipboard.copy(record.request.currentURL ?? record.request.url)
                } label: {
                    Label("URL", systemImage: "link")
                }
                .tint(.blue)
            }
    }
}

import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugSessionSwipeActionsModifier: ViewModifier {
    let session: ApxyDebugSession
    let isActive: Bool
    let onShare: (String) -> Void
    let onDelete: (String) -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    onShare(session.id)
                } label: {
                    Label("Share to Server", systemImage: "arrow.up.circle")
                }
                .tint(.blue)
                .disabled(!session.isShareable)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isActive {
                    Button(role: .destructive) {
                        onDelete(session.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
    }
}

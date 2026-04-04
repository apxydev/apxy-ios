import SwiftUI

struct ApxyDebugDetailListStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(macOS)
        content.listStyle(.automatic)
#else
        content
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugDetailListStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

#if os(macOS)
        content
            .listStyle(.automatic)
            .scrollContentBackground(.hidden)
            .background(theme.canvas.ignoresSafeArea())
            .listRowBackground(theme.surface)
#else
        content
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(theme.canvas.ignoresSafeArea())
            .listRowBackground(theme.surface)
            .apxyNavigationChrome(theme: theme, colorScheme: colorScheme)
#endif
    }
}

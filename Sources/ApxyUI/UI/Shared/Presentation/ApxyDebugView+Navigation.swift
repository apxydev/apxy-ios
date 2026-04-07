import SwiftUI

extension View {
    @ViewBuilder
    func apxyInlineTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func apxyLargeTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.large)
#else
        self
#endif
    }
}

@available(iOS 16.0, macOS 13.0, *)
extension View {
    @ViewBuilder
    func apxyVisibleNavigationBar() -> some View {
#if os(iOS)
        toolbar(.visible, for: .navigationBar)
#else
        self
#endif
    }

    @ViewBuilder
    func apxyNavigationChrome(
        theme: ApxyDebugThemePalette,
        colorScheme: ColorScheme
    ) -> some View {
#if os(iOS)
        toolbar(.visible, for: .navigationBar)
            .toolbarBackground(theme.canvas, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
#else
        self
#endif
    }
}

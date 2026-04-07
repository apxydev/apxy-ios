import SwiftUI

struct ApxyDebugStatusDot: View {
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay {
                Circle()
                    .stroke(theme.border.opacity(0.6), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

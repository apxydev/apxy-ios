import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugPlaceholderPanel: View {
    let title: String
    let systemImage: String
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        ApxyDebugSurfaceCard(style: .elevated) {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.accentSoft))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Placeholder Panel iOS") {
    ApxyDebugPlaceholderPanel(
        title: "No Request Selected",
        systemImage: "point.3.connected.trianglepath.dotted",
        message: "Pick a request from the list to inspect headers, body, cookies, and timing."
    )
    .padding()
    .apxyPreviewComponent(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Placeholder Panel macOS") {
    ApxyDebugPlaceholderPanel(
        title: "No Request Selected",
        systemImage: "point.3.connected.trianglepath.dotted",
        message: "Pick a request from the list to inspect headers, body, cookies, and timing."
    )
    .padding()
    .apxyPreviewComponent(.macOS)
}
#endif

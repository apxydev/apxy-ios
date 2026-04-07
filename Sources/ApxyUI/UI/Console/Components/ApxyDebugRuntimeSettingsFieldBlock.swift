import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRuntimeSettingsFieldBlock<Content: View>: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: ApxyDebugThemeTone
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        detail: String,
        systemImage: String,
        tint: ApxyDebugThemeTone = .accent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)
        let iconTint = tint.color(in: theme)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 32, height: 32)
                    .background(iconTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
                .font(.body)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.border)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

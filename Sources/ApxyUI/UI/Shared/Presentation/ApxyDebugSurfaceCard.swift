import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugSurfaceCard<Content: View>: View {
    enum Style {
        case plain
        case elevated
        case terminal
    }

    let style: Style
    var topAccent: Color? = nil
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        style: Style = .plain,
        topAccent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.topAccent = topAccent
        self.content = content()
    }

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        content
            .padding(ApxyDebugChrome.contentPadding)
            .background(
                backgroundStyle(theme: theme),
                in: RoundedRectangle(cornerRadius: ApxyDebugChrome.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ApxyDebugChrome.cardCornerRadius, style: .continuous)
                    .strokeBorder(borderColor(theme: theme))
            }
            .overlay {
                VStack(spacing: 0) {
                    if let topAccent {
                        topAccent
                            .frame(height: 3)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: ApxyDebugChrome.cardCornerRadius,
                                    topTrailingRadius: ApxyDebugChrome.cardCornerRadius
                                )
                            )
                    }
                    Spacer(minLength: 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ApxyDebugChrome.cardCornerRadius, style: .continuous))
            .shadow(color: theme.shadow, radius: style == .terminal ? 0 : 10, y: style == .terminal ? 0 : 4)
    }

    private func backgroundStyle(theme: ApxyDebugThemePalette) -> AnyShapeStyle {
        switch style {
        case .plain:
            AnyShapeStyle(ApxyDebugChrome.subtleFill(in: theme))
        case .elevated:
            AnyShapeStyle(ApxyDebugChrome.elevatedFill(in: theme))
        case .terminal:
            AnyShapeStyle(ApxyDebugChrome.terminalFill(in: theme))
        }
    }

    private func borderColor(theme: ApxyDebugThemePalette) -> Color {
        if topAccent != nil {
            return theme.accentBorder
        }
        return ApxyDebugChrome.subtleStroke(in: theme)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Surface Card Light iOS") {
    ApxyDebugSurfaceCard(style: .elevated, topAccent: ApxyDebugTheme.palette(for: .light).accent) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview Card")
                .font(.headline)
            Text("Shared preview fixtures keep SwiftUI previews readable and realistic.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .apxyPreviewComponent(.iOS)
    .preferredColorScheme(.light)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Surface Card Dark macOS") {
    ApxyDebugSurfaceCard(style: .elevated, topAccent: ApxyDebugTheme.palette(for: .dark).accent) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview Card")
                .font(.headline)
            Text("Shared preview fixtures keep SwiftUI previews readable and realistic.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .apxyPreviewComponent(.macOS)
    .preferredColorScheme(.dark)
}
#endif

import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugSurfaceCard<Content: View>: View {
    enum Style {
        case plain
        case material
    }

    let style: Style
    var topAccent: Color? = nil
    @ViewBuilder let content: Content

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
        content
            .padding(ApxyDebugChrome.contentPadding)
            .background(
                backgroundStyle,
                in: RoundedRectangle(cornerRadius: ApxyDebugChrome.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ApxyDebugChrome.cardCornerRadius, style: .continuous)
                    .strokeBorder(ApxyDebugChrome.subtleStroke)
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
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .plain:
            AnyShapeStyle(ApxyDebugChrome.subtleFill)
        case .material:
            AnyShapeStyle(.thinMaterial)
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Surface Card iOS") {
    ApxyDebugSurfaceCard(style: .material, topAccent: .blue) {
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
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Surface Card macOS") {
    ApxyDebugSurfaceCard(style: .material, topAccent: .blue) {
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
}
#endif

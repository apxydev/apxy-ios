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
            .padding(14)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .top) {
                if let topAccent {
                    topAccent
                        .frame(height: 3)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .plain:
            AnyShapeStyle(Color.secondary.opacity(0.08))
        case .material:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Surface Card") {
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
}
#endif

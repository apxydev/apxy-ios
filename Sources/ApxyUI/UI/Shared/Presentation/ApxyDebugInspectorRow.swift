import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugInspectorRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    var isEnabled: Bool = true
    var showsChevron: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isEnabled ? tint : theme.textMuted)
                .frame(width: ApxyDebugChrome.iconColumnWidth, alignment: .leading)

            Text(title)
                .lineLimit(2)
                .foregroundStyle(isEnabled ? theme.textPrimary : theme.textSecondary)

            Spacer()

            if !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(theme.textMuted)
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Inspector Row iOS") {
    ApxyDebugInspectorRow(
        icon: "chart.xyaxis.line",
        tint: .orange,
        title: "Metrics Timeline",
        detail: "1",
        isEnabled: true,
        showsChevron: true
    )
    .padding()
    .apxyPreviewComponent(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Inspector Row macOS") {
    ApxyDebugInspectorRow(
        icon: "chart.xyaxis.line",
        tint: .orange,
        title: "Metrics Timeline",
        detail: "1",
        isEnabled: true,
        showsChevron: true
    )
    .padding()
    .apxyPreviewComponent(.macOS)
}
#endif

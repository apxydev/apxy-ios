import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugInspectorRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    var isEnabled: Bool = true
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    isEnabled ? tint : Color.secondary,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            Text(title)
                .foregroundStyle(isEnabled ? .primary : .secondary)

            Spacer()

            if !detail.isEmpty {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Inspector Row") {
    ApxyDebugInspectorRow(
        icon: "chart.xyaxis.line",
        tint: .orange,
        title: "Metrics Timeline",
        detail: "1",
        isEnabled: true,
        showsChevron: true
    )
    .padding()
}
#endif

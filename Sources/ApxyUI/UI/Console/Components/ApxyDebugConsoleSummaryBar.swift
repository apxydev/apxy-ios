import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleSummaryBar: View {
    let totalCount: Int
    let failureCount: Int
    @Binding var selectedStatus: ApxyDebugStatusFilter
    @Environment(\.colorScheme) private var colorScheme

    private var successCount: Int {
        totalCount - failureCount
    }

    var body: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                modeButton(.all, title: "All", count: totalCount)
                modeButton(.failures, title: "Errors", count: failureCount, tone: .error)
                modeButton(.successes, title: "OK", count: successCount, tone: .success)
            }
            VStack(alignment: .leading, spacing: 8) {
                modeButton(.all, title: "All", count: totalCount)
                HStack(spacing: 8) {
                    modeButton(.failures, title: "Errors", count: failureCount, tone: .error)
                    modeButton(.successes, title: "OK", count: successCount, tone: .success)
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func modeButton(
        _ filter: ApxyDebugStatusFilter,
        title: String,
        count: Int,
        tone: ApxyDebugThemeTone = .accent
    ) -> some View {
        let isSelected = selectedStatus == filter
        let theme = ApxyDebugTheme.palette(for: colorScheme)
        let tint = tone.color(in: theme)

        return Button {
            selectedStatus = filter
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .bold()
                Text("\(count)")
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? AnyShapeStyle(theme.textPrimary) : AnyShapeStyle(theme.textSecondary))
            .background(
                isSelected
                    ? AnyShapeStyle(tint.opacity(0.18))
                    : AnyShapeStyle(ApxyDebugChrome.elevatedFill(in: theme)),
                in: RoundedRectangle(cornerRadius: ApxyDebugChrome.controlCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ApxyDebugChrome.controlCornerRadius, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.48) : ApxyDebugChrome.subtleStroke(in: theme))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
private struct ApxyDebugConsoleSummaryBarPreview: View {
    @State private var selectedStatus: ApxyDebugStatusFilter = .failures

    var body: some View {
        ApxyDebugConsoleSummaryBar(
            totalCount: ApxyDebugPreviewFixtures.records.count,
            failureCount: ApxyDebugPreviewFixtures.records.filter(\.isFailure).count,
            selectedStatus: $selectedStatus
        )
        .padding()
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Summary Bar iOS") {
    ApxyDebugConsoleSummaryBarPreview()
        .apxyPreviewControl(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Summary Bar macOS") {
    ApxyDebugConsoleSummaryBarPreview()
        .apxyPreviewControl(.macOS)
}
#endif

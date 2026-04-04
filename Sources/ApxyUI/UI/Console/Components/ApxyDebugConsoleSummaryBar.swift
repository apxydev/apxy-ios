import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleSummaryBar: View {
    let totalCount: Int
    let failureCount: Int
    @Binding var selectedStatus: ApxyDebugStatusFilter

    private var successCount: Int {
        totalCount - failureCount
    }

    var body: some View {
        HStack(spacing: 8) {
            modeButton(.all, title: "All", count: totalCount)
            modeButton(.failures, title: "Errors", count: failureCount, tint: .red)
            modeButton(.successes, title: "OK", count: successCount, tint: .green)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func modeButton(
        _ filter: ApxyDebugStatusFilter,
        title: String,
        count: Int,
        tint: Color = .accentColor
    ) -> some View {
        let isSelected = selectedStatus == filter

        return Button {
            selectedStatus = filter
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text("\(count)")
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .secondary)
            .background(
                isSelected
                    ? AnyShapeStyle(tint)
                    : AnyShapeStyle(Color.secondary.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
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
#Preview("Summary Bar") {
    ApxyDebugConsoleSummaryBarPreview()
}
#endif

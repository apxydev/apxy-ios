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
        ViewThatFits {
            horizontalContent
            verticalContent
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var horizontalContent: some View {
        HStack(alignment: .center, spacing: 12) {
            statusButtons
            Spacer(minLength: 12)
            totalsLabel
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusButtons
            totalsLabel
        }
    }

    private var statusButtons: some View {
        HStack(spacing: 8) {
            statusButton(title: "All", count: totalCount, filter: .all, tint: .accentColor)
            statusButton(title: "Errors", count: failureCount, filter: .failures, tint: .red)
            statusButton(title: "Success", count: successCount, filter: .successes, tint: .green)
        }
        .buttonStyle(.plain)
    }

    private var totalsLabel: some View {
        Text("\(totalCount) request\(totalCount == 1 ? "" : "s")")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func statusButton(
        title: String,
        count: Int,
        filter: ApxyDebugStatusFilter,
        tint: Color
    ) -> some View {
        let isSelected = selectedStatus == filter

        return Button {
            selectedStatus = filter
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text("\(count)")
                    .font(.footnote)
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? tint : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordRow: View {
    let record: ApxyDebugRecord
    var isHighlighted: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        VStack(alignment: .leading, spacing: ApxyDebugChrome.compactRowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ApxyDebugStatusDot(color: statusColor)

                Text(record.request.method)
                    .font(.caption.smallCaps())
                    .bold()
                    .foregroundStyle(theme.textSecondary)

                if record.isMocked {
                    mockBadge
                }

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)

                Spacer()

                Text(ApxyDebugValueFormatters.compactTimestamp(record.capturedAt))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.textMuted)
            }

            Text(primaryTitle)
                .font(.body)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Text(secondaryTitle)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(1)

                Spacer()

                if record.redirectCount > 0 {
                    Label("\(record.redirectCount)", systemImage: "arrow.triangle.swap")
                        .font(.caption)
                        .foregroundStyle(theme.warning)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(rowBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ApxyDebugChrome.controlCornerRadius, style: .continuous)
                .stroke(isHighlighted ? theme.accentBorder : theme.border, lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.35), value: isHighlighted)
        .clipShape(RoundedRectangle(cornerRadius: ApxyDebugChrome.controlCornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.request.method) \(record.request.host) \(record.request.path)")
        .accessibilityValue("\(statusText), \(footerText)")
    }

    private var primaryTitle: String {
        if let currentHost = record.request.currentHost, currentHost != record.request.host {
            return "\(record.request.host) -> \(currentHost)"
        }
        return record.request.host
    }

    private var secondaryTitle: String {
        if let currentPath = record.request.currentPath,
           currentPath != record.request.path {
            return "\(record.request.path) -> \(currentPath)"
        }
        return record.request.path
    }

    private var footerText: String {
        var items = [ApxyDebugValueFormatters.duration(record.duration)]
        if let responseSize = record.transfer.responseBodyBytesAfterDecoding ?? record.response?.bodySize {
            items.append(ApxyDebugValueFormatters.bytes(responseSize))
        }
        if let sessionID = record.sessionID, !sessionID.isEmpty {
            items.append("Session \(ApxyDebugValueFormatters.sessionPrefix(sessionID))")
        }
        return items.joined(separator: " / ")
    }

    private var statusText: String {
        if let response = record.response {
            return "\(response.statusCode)"
        }
        if let error = record.error {
            return error.message
        }
        return "Pending"
    }

    private var statusPresentation: ApxyDebugStatusPresentation {
        .from(record: record)
    }

    private var theme: ApxyDebugThemePalette {
        ApxyDebugTheme.palette(for: colorScheme)
    }

    private var statusColor: Color { statusPresentation.color(in: theme) }

    private var rowBackground: some ShapeStyle {
        isHighlighted
            ? AnyShapeStyle(ApxyDebugChrome.selectedFill(in: theme))
            : AnyShapeStyle(ApxyDebugChrome.elevatedFill(in: theme))
    }

    private var mockBadge: some View {
        Text("MOCK")
            .font(.caption)
            .bold()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(theme.surface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.border)
            }
            .foregroundStyle(theme.textSecondary)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Row Success iOS") {
    ApxyDebugRecordRow(record: ApxyDebugPreviewFixtures.redirectedRecord)
        .padding()
        .apxyPreviewRow(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Row Success macOS") {
    ApxyDebugRecordRow(record: ApxyDebugPreviewFixtures.redirectedRecord)
        .padding()
        .apxyPreviewRow(.macOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Row Failure iOS") {
    ApxyDebugRecordRow(
        record: ApxyDebugPreviewFixtures.failedRecord,
        isHighlighted: true
    )
    .padding()
    .apxyPreviewRow(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Row Failure macOS") {
    ApxyDebugRecordRow(
        record: ApxyDebugPreviewFixtures.failedRecord,
        isHighlighted: true
    )
    .padding()
    .apxyPreviewRow(.macOS)
}
#endif

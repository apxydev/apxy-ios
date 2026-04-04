import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordRow: View {
    let record: ApxyDebugRecord
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ApxyDebugChrome.compactRowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ApxyDebugStatusDot(color: statusColor)

                Text(record.request.method)
                    .font(.caption.smallCaps())
                    .bold()
                    .foregroundStyle(.secondary)

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
                    .foregroundStyle(.secondary)
            }

            Text(primaryTitle)
                .font(.body)
                .lineLimit(1)

            Text(secondaryTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if record.redirectCount > 0 {
                    Label("\(record.redirectCount)", systemImage: "arrow.triangle.swap")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(rowBackground)
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
            items.append("Session \(String(sessionID.prefix(8)))")
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

    private var statusColor: Color { statusPresentation.color }

    private var rowBackground: some ShapeStyle {
        isHighlighted
            ? AnyShapeStyle(ApxyDebugChrome.selectedFill)
            : AnyShapeStyle(Color.clear)
    }

    private var mockBadge: some View {
        Text("MOCK")
            .font(.caption)
            .bold()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.18), in: Capsule())
            .foregroundStyle(.secondary)
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

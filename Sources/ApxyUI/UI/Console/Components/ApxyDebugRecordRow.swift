import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordRow: View {
    let record: ApxyDebugRecord
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: statusIconName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(statusColor, in: Circle())

                Text(record.request.method)
                    .font(.caption.weight(.semibold).smallCaps())
                    .foregroundStyle(.secondary)

                Text(primaryTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text(ApxyDebugValueFormatters.compactTimestamp(record.capturedAt))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if record.isMocked {
                    Text("MOCK")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.55), in: Capsule())
                }

                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)

                if record.redirectCount > 0 {
                    Label("\(record.redirectCount)", systemImage: "arrow.triangle.swap")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            Text(secondaryTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(footerText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(rowBackground)
        .animation(.easeOut(duration: 0.5), value: isHighlighted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.request.method) \(record.request.host)")
        .accessibilityValue("\(statusText), \(ApxyDebugValueFormatters.duration(record.duration))")
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
    private var statusIconName: String { statusPresentation.iconName }

    private var rowBackground: some ShapeStyle {
        isHighlighted
            ? AnyShapeStyle(Color.accentColor.opacity(0.16))
            : AnyShapeStyle(Color.clear)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Row Success") {
    ApxyDebugRecordRow(record: ApxyDebugPreviewFixtures.redirectedRecord)
        .padding()
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Row Failure") {
    ApxyDebugRecordRow(
        record: ApxyDebugPreviewFixtures.failedRecord,
        isHighlighted: true
    )
    .padding()
}
#endif

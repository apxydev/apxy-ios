import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordRow: View {
    let record: ApxyDebugRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)

                Spacer()

                Text(ApxyDebugValueFormatters.compactTimestamp(record.capturedAt))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if record.isMocked {
                    Text("MOCK")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.16))
                        .clipShape(Capsule())
                }

                Text(record.request.method)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(primaryTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
            }

            Text(secondaryTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    private var primaryTitle: String {
        record.request.currentPath ?? record.request.path
    }

    private var secondaryTitle: String {
        if let currentHost = record.request.currentHost,
           currentHost != record.request.host {
            return "\(record.request.host) -> \(currentHost)"
        }
        return record.request.host
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

    private var statusColor: Color {
        if record.error != nil {
            return .red
        }
        if let statusCode = record.response?.statusCode {
            switch statusCode {
            case 200..<400:
                return .green
            case 400...:
                return .red
            default:
                return .orange
            }
        }
        return .orange
    }
}

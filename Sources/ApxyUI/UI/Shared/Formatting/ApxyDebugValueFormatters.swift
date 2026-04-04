import Foundation
import ApxyCore

enum ApxyDebugValueFormatters {
    static func timestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    static func compactTimestamp(_ date: Date) -> String {
        compactTimestampFormatter.string(from: date)
    }

    static func duration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1_000)
        }
        return String(format: "%.2f s", duration)
    }

    static func bytes(_ value: Int64?) -> String {
        guard let value else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func headers(_ headers: [String: String]) -> String {
        if headers.isEmpty {
            return "No headers"
        }

        return headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    static func sessionTitle(_ session: ApxyDebugSession) -> String {
        let prefix = String(session.id.prefix(8))
        return "\(prefix) · \(session.requestCount) request\(session.requestCount == 1 ? "" : "s")"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let compactTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

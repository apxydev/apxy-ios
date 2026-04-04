import Foundation

enum ApxyDebugBodyFormatter {
    enum Presentation: Equatable {
        case empty
        case unavailable
        case text(String)
        case binary(summary: String)
    }

    static func presentation(data: Data?, contentType: String?, bodySize: Int64?) -> Presentation {
        if let data {
            if data.isEmpty {
                return .empty
            }

            if isLikelyJSON(contentType: contentType),
               let object = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: pretty, encoding: .utf8) {
                return .text(text)
            }

            if let text = String(data: data, encoding: .utf8) {
                return .text(text)
            }

            return .binary(summary: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
        }

        if let bodySize, bodySize > 0 {
            return .unavailable
        }

        return .empty
    }

    static func displayText(data: Data?, contentType: String?, bodySize: Int64? = nil) -> String? {
        switch presentation(data: data, contentType: contentType, bodySize: bodySize) {
        case .empty:
            return "Empty body"
        case .unavailable:
            return nil
        case let .text(text):
            return text
        case let .binary(summary):
            return "Binary body (\(summary))"
        }
    }

    static func searchableText(data: Data?, contentType: String?, bodySize: Int64? = nil) -> String {
        displayText(data: data, contentType: contentType, bodySize: bodySize) ?? ""
    }

    private static func isLikelyJSON(contentType: String?) -> Bool {
        guard let contentType else { return false }
        let normalized = contentType.lowercased()
        return normalized.contains("json") || normalized.contains("+json")
    }
}

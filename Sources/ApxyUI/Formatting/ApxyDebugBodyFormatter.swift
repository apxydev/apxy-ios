import Foundation

enum ApxyDebugBodyFormatter {
    static func displayText(data: Data?, contentType: String?) -> String? {
        guard let data else { return nil }
        if data.isEmpty {
            return "Empty body"
        }

        if isLikelyJSON(contentType: contentType),
           let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        return "Binary body (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))"
    }

    static func searchableText(data: Data?, contentType: String?) -> String {
        displayText(data: data, contentType: contentType) ?? ""
    }

    private static func isLikelyJSON(contentType: String?) -> Bool {
        guard let contentType else { return false }
        let normalized = contentType.lowercased()
        return normalized.contains("json") || normalized.contains("+json")
    }
}

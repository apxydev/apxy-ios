import Foundation
import ApxyCore

enum ApxyDebugCurlFormatter {
    static func makeCurl(for record: ApxyDebugRecord, useCurrentRequest: Bool) -> String {
        let method = record.request.method
        let url = useCurrentRequest ? (record.request.currentURL ?? record.request.url) : record.request.url
        let headers = useCurrentRequest && !record.request.currentHeaders.isEmpty
            ? record.request.currentHeaders
            : record.request.headers

        var lines = [
            "curl -X \(shellEscape(method))",
            "  \(shellEscape(url))"
        ]

        for header in headers.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            let headerValue = "\(header.key): \(header.value)"
            lines.append("  -H \(shellEscape(headerValue))")
        }

        if let body = record.request.body, !body.isEmpty {
            if let text = String(data: body, encoding: .utf8) {
                lines.append("  --data-raw \(shellEscape(text))")
            } else {
                lines.append("  --data-binary '<binary body omitted>'")
            }
        }

        return lines.joined(separator: " \\\n")
    }

    private static func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }
}

import Foundation

enum ApxyDebugCookiesFormatter {
    static func cookies(headers: [String: String], urlString: String) -> [HTTPCookie] {
        guard !headers.isEmpty, let url = URL(string: urlString) else {
            return []
        }

        let requestCookies = makeRequestCookies(headers: headers, url: url)
        let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)

        return (requestCookies + responseCookies)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func detailsText(for cookies: [HTTPCookie]) -> String {
        guard !cookies.isEmpty else {
            return "No cookies"
        }

        return cookies.map { cookie in
            var lines = [
                "Name: \(cookie.name)",
                "Value: \(cookie.value)",
                "Domain: \(cookie.domain)",
                "Path: \(cookie.path)",
                "Secure: \(cookie.isSecure ? "Yes" : "No")",
                "Session Only: \(cookie.isSessionOnly ? "Yes" : "No")"
            ]
            if let expiresDate = cookie.expiresDate {
                lines.append("Expires: \(ApxyDebugValueFormatters.timestamp(expiresDate))")
            }
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private static func makeRequestCookies(headers: [String: String], url: URL) -> [HTTPCookie] {
        guard let cookieHeader = headers.first(where: { $0.key.caseInsensitiveCompare("Cookie") == .orderedSame })?.value else {
            return []
        }

        return cookieHeader
            .split(separator: ";")
            .compactMap { component in
                let pair = component.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard pair.count == 2, !pair[0].isEmpty else {
                    return nil
                }
                return HTTPCookie(properties: [
                    .name: pair[0],
                    .value: pair[1],
                    .domain: url.host ?? "",
                    .path: "/"
                ])
            }
    }
}

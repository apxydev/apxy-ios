import Foundation

/// Allowlist for which request hosts are captured when `capturedDomains` is non-empty.
struct DomainFilter: Sendable {
    private let exact: Set<String>
    private let wildcardSuffixes: [String]

    /// - Parameter domains: Patterns: exact host (e.g. `api.example.com`) or `*.example.com` for any subdomain.
    init(domains: [String]) {
        var exactSet = Set<String>()
        var suffixes: [String] = []
        exactSet.reserveCapacity(domains.count)
        for raw in domains {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            if lower.hasPrefix("*.") {
                let rest = String(lower.dropFirst(2))
                guard !rest.isEmpty else { continue }
                // `*.example.com` → hosts ending with `.example.com` (not bare `example.com`).
                suffixes.append("." + rest)
            } else {
                exactSet.insert(lower)
            }
        }
        self.exact = exactSet
        self.wildcardSuffixes = suffixes
    }

    /// Returns whether `host` matches any exact or wildcard pattern.
    func matches(host: String) -> Bool {
        let h = host.lowercased()
        if exact.contains(h) { return true }
        return wildcardSuffixes.contains { h.hasSuffix($0) }
    }
}

import Testing
@testable import ApxyCore

struct DomainFilterTests {
    struct Row: Sendable {
        let domains: [String]
        let host: String
        let expected: Bool
    }

    @Test(arguments: [
        Row(domains: ["api.example.com"], host: "api.example.com", expected: true),
        Row(domains: ["api.example.com"], host: "other.example.com", expected: false),
        Row(domains: ["API.Example.COM"], host: "Api.Example.Com", expected: true),
        Row(domains: ["*.example.com"], host: "api.example.com", expected: true),
        Row(domains: ["*.example.com"], host: "example.com", expected: false),
        Row(domains: ["*.Analytics.IO"], host: "track.analytics.io", expected: true),
        Row(domains: ["api.myapp.com", "*.analytics.io"], host: "x.analytics.io", expected: true),
        Row(domains: ["  api.example.com  "], host: "api.example.com", expected: true),
        Row(domains: ["", "   ", "*."], host: "anything.com", expected: false),
    ])
    func matchesExpectedHostPatterns(row: Row) {
        let filter = DomainFilter(domains: row.domains)
        #expect(filter.matches(host: row.host) == row.expected)
    }
}

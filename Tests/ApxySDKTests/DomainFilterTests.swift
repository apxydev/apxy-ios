import XCTest
@testable import ApxySDK

final class DomainFilterTests: XCTestCase {

    func testExactMatch() {
        let f = DomainFilter(domains: ["api.example.com"])
        XCTAssertTrue(f.matches(host: "api.example.com"))
        XCTAssertFalse(f.matches(host: "other.example.com"))
        XCTAssertFalse(f.matches(host: "example.com"))
    }

    func testExactMatchCaseInsensitive() {
        let f = DomainFilter(domains: ["API.Example.COM"])
        XCTAssertTrue(f.matches(host: "api.example.com"))
        XCTAssertTrue(f.matches(host: "Api.Example.Com"))
    }

    func testWildcardSubdomain() {
        let f = DomainFilter(domains: ["*.example.com"])
        XCTAssertTrue(f.matches(host: "api.example.com"))
        XCTAssertTrue(f.matches(host: "v2.api.example.com"))
        XCTAssertFalse(f.matches(host: "example.com"))
        XCTAssertFalse(f.matches(host: "notexample.com"))
    }

    func testWildcardCaseInsensitive() {
        let f = DomainFilter(domains: ["*.Analytics.IO"])
        XCTAssertTrue(f.matches(host: "track.analytics.io"))
    }

    func testMultiplePatterns() {
        let f = DomainFilter(domains: ["api.myapp.com", "*.analytics.io"])
        XCTAssertTrue(f.matches(host: "api.myapp.com"))
        XCTAssertTrue(f.matches(host: "x.analytics.io"))
        XCTAssertFalse(f.matches(host: "myapp.com"))
    }

    func testTrimsWhitespace() {
        let f = DomainFilter(domains: ["  api.example.com  "])
        XCTAssertTrue(f.matches(host: "api.example.com"))
    }

    func testEmptyPatternsNeverMatch() {
        let f = DomainFilter(domains: ["", "   ", "*."])
        XCTAssertFalse(f.matches(host: "anything.com"))
    }

    func testTableDriven() {
        struct Row {
            let domains: [String]
            let host: String
            let expected: Bool
        }
        let rows: [Row] = [
            Row(domains: ["h.com"], host: "h.com", expected: true),
            Row(domains: ["*.h.com"], host: "a.h.com", expected: true),
            Row(domains: ["*.h.com"], host: "h.com", expected: false),
            Row(domains: ["sub.example.com"], host: "sub.example.com", expected: true),
            Row(domains: ["sub.example.com"], host: "other.example.com", expected: false),
        ]
        for row in rows {
            let f = DomainFilter(domains: row.domains)
            XCTAssertEqual(
                f.matches(host: row.host),
                row.expected,
                "domains=\(row.domains) host=\(row.host)"
            )
        }
    }
}

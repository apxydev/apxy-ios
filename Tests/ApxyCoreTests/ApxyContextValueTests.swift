import Foundation
import Testing
@testable import ApxyCore

struct ApxyContextValueTests {
    @Test func makeConvertsNestedJSONValues() {
        let input: [String: Any] = [
            "plan": "pro",
            "active": true,
            "limits": ["requests": 10],
            "features": ["ws", "http"]
        ]

        let value = ApxyContextValue.make(from: input)

        #expect(
            value == .object([
                "plan": "pro",
                "active": true,
                "limits": .object(["requests": 10]),
                "features": .array(["ws", "http"])
            ])
        )
    }

    @Test func makeRejectsUnsupportedValues() {
        final class Unsupported {}
        #expect(ApxyContextValue.make(from: Unsupported()) == nil)
    }
}

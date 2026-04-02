import XCTest
@testable import ApxySDK

final class ClientIdentityTests: XCTestCase {

    func testBuildReturnsNonEmptyID() {
        let client = ClientIdentity.build()
        XCTAssertFalse(client.id.isEmpty)
        XCTAssertFalse(client.platform.isEmpty)
        XCTAssertFalse(client.osName.isEmpty)
    }

    func testDeterministicID() {
        let a = ClientIdentity.build()
        let b = ClientIdentity.build()
        XCTAssertEqual(a.id, b.id, "Same device/app must produce the same client ID")
    }

    func testIDLength() {
        let client = ClientIdentity.build()
        // SHA256 hex digest = 64 chars
        XCTAssertEqual(client.id.count, 64)
    }
}

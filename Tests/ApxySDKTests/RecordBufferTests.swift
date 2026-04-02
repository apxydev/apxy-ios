import XCTest
@testable import ApxySDK

final class RecordBufferTests: XCTestCase {

    func testAppendAndDrain() {
        let buffer = RecordBuffer(capacity: 5)
        let record = makeRecord(id: "r1")
        buffer.append(record)
        let drained = buffer.drain()
        XCTAssertEqual(drained.count, 1)
        XCTAssertEqual(drained[0].id, "r1")
        XCTAssertEqual(buffer.count, 0)
    }

    func testRingBufferDropsOldest() {
        let buffer = RecordBuffer(capacity: 3)
        for i in 1...5 {
            buffer.append(makeRecord(id: "r\(i)"))
        }
        let drained = buffer.drain()
        XCTAssertEqual(drained.count, 3)
        XCTAssertEqual(drained.map(\.id), ["r3", "r4", "r5"])
    }

    func testDrainIsNonDestructiveOnEmpty() {
        let buffer = RecordBuffer(capacity: 10)
        XCTAssertTrue(buffer.drain().isEmpty)
    }

    func testThreadSafety() {
        let buffer = RecordBuffer(capacity: 1000)
        let expectation = XCTestExpectation(description: "concurrent writes")
        let group = DispatchGroup()
        for i in 0..<100 {
            group.enter()
            DispatchQueue.global().async {
                buffer.append(self.makeRecord(id: "r\(i)"))
                group.leave()
            }
        }
        group.notify(queue: .main) {
            XCTAssertLessThanOrEqual(buffer.count, 1000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: Helpers

    private func makeRecord(id: String) -> NetworkRecord {
        NetworkRecord(
            id: id,
            timestamp: Date(),
            method: "GET",
            url: "https://example.com/\(id)",
            host: "example.com",
            path: "/\(id)",
            statusCode: 200,
            duration: 1_000_000,
            tls: true,
            mocked: false
        )
    }
}

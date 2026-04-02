import Foundation
import Testing
@testable import ApxySDK

struct RecordBufferTests {
    @Test func appendAndDrain() async throws {
        let buffer = RecordBuffer(capacity: 5)
        await buffer.append(makeRecord(id: "r1"))

        let drained = await buffer.drain()
        let first = try #require(drained.first)

        #expect(drained.count == 1)
        #expect(first.id == "r1")
        #expect(await buffer.count == 0)
    }

    @Test func ringBufferDropsOldestRecords() async {
        let buffer = RecordBuffer(capacity: 3)

        for index in 1...5 {
            await buffer.append(makeRecord(id: "r\(index)"))
        }

        let drained = await buffer.drain()
        #expect(drained.map(\.id) == ["r3", "r4", "r5"])
    }

    @Test func prependRestoresOlderRecordsAheadOfNewerOnes() async {
        let buffer = RecordBuffer(capacity: 5)
        await buffer.append(makeRecord(id: "r3"))
        await buffer.append(makeRecord(id: "r4"))
        await buffer.prepend([makeRecord(id: "r1"), makeRecord(id: "r2")])

        #expect(await buffer.drain().map(\.id) == ["r1", "r2", "r3", "r4"])
    }

    @Test func prependStillHonorsCapacity() async {
        let buffer = RecordBuffer(capacity: 3)
        await buffer.append(makeRecord(id: "r4"))
        await buffer.append(makeRecord(id: "r5"))
        await buffer.prepend([makeRecord(id: "r1"), makeRecord(id: "r2"), makeRecord(id: "r3")])

        #expect(await buffer.drain().map(\.id) == ["r3", "r4", "r5"])
    }

    @Test func concurrentWritesDoNotLoseOrDuplicateRecords() async {
        let buffer = RecordBuffer(capacity: 1_000)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    await buffer.append(makeRecord(id: "r\(index)"))
                }
            }
        }

        let drained = await buffer.drain()
        #expect(drained.count == 100)
        #expect(Set(drained.map(\.id)).count == 100)
    }

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

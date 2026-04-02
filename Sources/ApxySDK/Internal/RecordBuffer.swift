import Foundation

/// Thread-safe in-memory ring buffer that holds captured `NetworkRecord`s until
/// they can be flushed to APXY Core. Oldest records are silently dropped when
/// the buffer is full, ensuring no memory growth under disconnection.
final class RecordBuffer: @unchecked Sendable {
    private let capacity: Int
    private var storage: [NetworkRecord]
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = []
        self.storage.reserveCapacity(self.capacity)
    }

    func append(_ record: NetworkRecord) {
        lock.lock()
        defer { lock.unlock() }
        if storage.count >= capacity {
            storage.removeFirst()
            SDKLogger.debug("ring buffer full; dropped oldest record (capacity=\(capacity))")
        }
        storage.append(record)
    }

    func drain() -> [NetworkRecord] {
        lock.lock()
        defer { lock.unlock() }
        let records = storage
        storage.removeAll(keepingCapacity: true)
        return records
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

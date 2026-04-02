import Foundation

/// Thread-safe in-memory ring buffer that holds captured `NetworkRecord`s until
/// they can be flushed to APXY Core. Oldest records are silently dropped when
/// the buffer is full, ensuring no memory growth under disconnection.
actor RecordBuffer {
    private let capacity: Int
    private var storage: [NetworkRecord]

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = []
        self.storage.reserveCapacity(self.capacity)
    }

    func append(_ record: NetworkRecord) {
        if storage.count >= capacity {
            storage.removeFirst()
            SDKLogger.debug("ring buffer full; dropped oldest record (capacity=\(capacity))")
        }
        storage.append(record)
    }

    func prepend(_ records: [NetworkRecord]) {
        guard !records.isEmpty else { return }

        storage.insert(contentsOf: records, at: 0)
        if storage.count > capacity {
            let overflow = storage.count - capacity
            storage.removeFirst(overflow)
            SDKLogger.debug(
                "ring buffer full; dropped \(overflow) oldest re-queued record(s) (capacity=\(capacity))"
            )
        }
    }

    func drain() -> [NetworkRecord] {
        let records = storage
        storage.removeAll(keepingCapacity: true)
        return records
    }

    var count: Int {
        return storage.count
    }
}

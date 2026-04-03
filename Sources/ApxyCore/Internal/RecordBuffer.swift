import Foundation

/// Thread-safe in-memory ring buffer that holds captured `NetworkRecord`s until
/// they can be flushed to APXY Core. Oldest records are silently dropped when
/// the buffer is full, ensuring no memory growth under disconnection.
actor RecordBuffer {
    private let capacity: Int
    private var storage: [NetworkRecord?]
    private var head = 0
    private var countStorage = 0

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = Array(repeating: nil, count: self.capacity)
    }

    func append(_ record: NetworkRecord) {
        if countStorage == capacity {
            storage[head] = record
            head = (head + 1) % capacity
            SDKLogger.debug("ring buffer full; dropped oldest record (capacity=\(capacity))")
            return
        }

        let index = (head + countStorage) % capacity
        storage[index] = record
        countStorage += 1
    }

    func prepend(_ records: [NetworkRecord]) {
        guard !records.isEmpty else { return }

        let combined = records + orderedRecords()
        let kept = Array(combined.suffix(capacity))
        rebuild(with: kept)
        let overflow = combined.count - kept.count
        if overflow > 0 {
            SDKLogger.debug(
                "ring buffer full; dropped \(overflow) oldest re-queued record(s) (capacity=\(capacity))"
            )
        }
    }

    func drain() -> [NetworkRecord] {
        let records = orderedRecords()
        storage = Array(repeating: nil, count: capacity)
        head = 0
        countStorage = 0
        return records
    }

    var count: Int {
        countStorage
    }

    private func orderedRecords() -> [NetworkRecord] {
        guard countStorage > 0 else { return [] }
        var records: [NetworkRecord] = []
        records.reserveCapacity(countStorage)
        for offset in 0..<countStorage {
            let index = (head + offset) % capacity
            if let record = storage[index] {
                records.append(record)
            }
        }
        return records
    }

    private func rebuild(with records: [NetworkRecord]) {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        countStorage = 0
        for record in records {
            let index = (head + countStorage) % capacity
            storage[index] = record
            countStorage += 1
        }
    }
}

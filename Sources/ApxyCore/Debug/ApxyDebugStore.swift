import Foundation

/// Actor-backed local store used by the embedded Apxy debug console.
public actor ApxyDebugStore {
    private struct SessionEntry: Sendable {
        let capturedAt: Date
        let isFailure: Bool
    }

    private struct SessionBucket: Sendable {
        var entries: [SessionEntry]
        var failureCount: Int
    }

    public let options: ApxyDebugOptions

    private static let persistenceDebounceNanoseconds: UInt64 = 1_000_000_000

    private let fileURL: URL
    private var persistedRecords: [ApxyDebugRecord]
    private var sessionBucketsByID: [String: SessionBucket]
    private var continuations: [UUID: AsyncStream<ApxyDebugSnapshot>.Continuation]
    private var persistTask: Task<Void, Never>?
    private var hasPendingPersistence = false
    private var persistWriteCount = 0

    public init(options: ApxyDebugOptions) {
        self.options = options
        self.fileURL = Self.resolveStoreURL(options: options)
        let loadedRecords = Self.loadPersistedRecords(from: fileURL)
        let persistedLimit = max(1, options.persistedRecordLimit)
        self.persistedRecords = Array(loadedRecords.prefix(persistedLimit))
        self.sessionBucketsByID = Self.makeSessionBuckets(from: self.persistedRecords)
        self.continuations = [:]
    }

    public func append(_ record: ApxyDebugRecord) {
        persistedRecords.insert(record, at: 0)
        appendSessionEntry(for: record)
        trimPersistedRecordsIfNeeded()
        schedulePersist()
        broadcastSnapshot()
    }

    public func clear() {
        persistTask?.cancel()
        persistTask = nil
        hasPendingPersistence = false
        persistedRecords.removeAll(keepingCapacity: false)
        sessionBucketsByID.removeAll(keepingCapacity: false)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            // Ignore missing stores.
        } catch {
            SDKLogger.warn("ApxyDebugStore failed clearing store: \(error.localizedDescription)")
        }
        broadcastSnapshot()
    }

    public func snapshot() -> ApxyDebugSnapshot {
        makeSnapshot()
    }

    func flush() async {
        persistTask?.cancel()
        persistTask = nil
        flushPersistenceIfNeeded()
    }

    var persistWriteCountForTesting: Int {
        persistWriteCount
    }

    public func updates() -> AsyncStream<ApxyDebugSnapshot> {
        let identifier = UUID()
        return AsyncStream { continuation in
            continuations[identifier] = continuation
            continuation.yield(makeSnapshot())
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.removeContinuation(identifier)
                }
            }
        }
    }

    private func removeContinuation(_ identifier: UUID) {
        continuations.removeValue(forKey: identifier)
    }

    private func makeSnapshot() -> ApxyDebugSnapshot {
        let records = Array(persistedRecords.prefix(max(1, options.memoryRecordLimit)))
        return ApxyDebugSnapshot(
            records: records,
            sessions: makeSessions()
        )
    }

    private func makeSessions() -> [ApxyDebugSession] {
        sessionBucketsByID.compactMap { key, bucket in
            guard let newest = bucket.entries.first, let oldest = bucket.entries.last else { return nil }
            return ApxyDebugSession(
                id: key,
                startedAt: oldest.capturedAt,
                lastEventAt: newest.capturedAt,
                requestCount: bucket.entries.count,
                failureCount: bucket.failureCount
            )
        }
        .sorted { $0.lastEventAt > $1.lastEventAt }
    }

    private func trimPersistedRecordsIfNeeded() {
        let limit = max(1, options.persistedRecordLimit)
        while persistedRecords.count > limit {
            let removed = persistedRecords.removeLast()
            removeSessionEntry(for: removed)
        }
    }

    private func schedulePersist() {
        hasPendingPersistence = true
        guard persistTask == nil else { return }

        persistTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.persistenceDebounceNanoseconds)
            } catch {
                return
            }
            await self?.completeScheduledPersist()
        }
    }

    private func completeScheduledPersist() async {
        persistTask = nil
        flushPersistenceIfNeeded()
    }

    private func flushPersistenceIfNeeded() {
        guard hasPendingPersistence else { return }
        hasPendingPersistence = false

        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(persistedRecords)
            try data.write(to: fileURL, options: [.atomic])
            persistWriteCount += 1
        } catch {
            hasPendingPersistence = true
            SDKLogger.warn("ApxyDebugStore failed persisting store: \(error.localizedDescription)")
        }
    }

    private func broadcastSnapshot() {
        let snapshot = makeSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private static func resolveStoreURL(options: ApxyDebugOptions) -> URL {
        if let storeURL = options.storeURL {
            return storeURL
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL
            .appendingPathComponent("ApxyCore", isDirectory: true)
            .appendingPathComponent("DebugConsole", isDirectory: true)
            .appendingPathComponent("records.json", isDirectory: false)
    }

    private static func loadPersistedRecords(from fileURL: URL) -> [ApxyDebugRecord] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let records = try? decoder.decode([ApxyDebugRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.capturedAt > $1.capturedAt }
    }

    private static func makeSessionBuckets(from records: [ApxyDebugRecord]) -> [String: SessionBucket] {
        var bucketsByID: [String: SessionBucket] = [:]
        for record in records {
            let sessionID = record.sessionID ?? "unsessioned"
            var bucket = bucketsByID[sessionID] ?? SessionBucket(entries: [], failureCount: 0)
            bucket.entries.append(SessionEntry(capturedAt: record.capturedAt, isFailure: record.isFailure))
            if record.isFailure {
                bucket.failureCount += 1
            }
            bucketsByID[sessionID] = bucket
        }
        return bucketsByID
    }

    private func appendSessionEntry(for record: ApxyDebugRecord) {
        let sessionID = record.sessionID ?? "unsessioned"
        var bucket = sessionBucketsByID[sessionID] ?? SessionBucket(entries: [], failureCount: 0)
        bucket.entries.insert(SessionEntry(capturedAt: record.capturedAt, isFailure: record.isFailure), at: 0)
        if record.isFailure {
            bucket.failureCount += 1
        }
        sessionBucketsByID[sessionID] = bucket
    }

    private func removeSessionEntry(for record: ApxyDebugRecord) {
        let sessionID = record.sessionID ?? "unsessioned"
        guard var bucket = sessionBucketsByID[sessionID], !bucket.entries.isEmpty else { return }
        let removedEntry = bucket.entries.removeLast()
        if removedEntry.isFailure {
            bucket.failureCount = max(0, bucket.failureCount - 1)
        }
        if bucket.entries.isEmpty {
            sessionBucketsByID.removeValue(forKey: sessionID)
        } else {
            sessionBucketsByID[sessionID] = bucket
        }
    }
}

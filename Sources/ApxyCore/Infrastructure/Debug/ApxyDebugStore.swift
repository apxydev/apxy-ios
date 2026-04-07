import Foundation

/// Actor-backed local store used by the embedded Apxy debug console.
public actor ApxyDebugStore {
    private enum StoreError: LocalizedError {
        case sessionNotFound(String)
        case sessionNotShareable(String)

        var errorDescription: String? {
            switch self {
            case .sessionNotFound(let id):
                return "Local session '\(id)' was not found"
            case .sessionNotShareable(let id):
                return "Local session '\(id)' cannot be shared in its current state"
            }
        }
    }

    private struct PersistedIndex: Codable {
        var sessions: [ApxyLocalSession]
    }

    struct SessionSharePayload: Sendable {
        let session: ApxyLocalSession
        let records: [NetworkRecord]
    }

    public let options: ApxyDebugOptions

    private static let persistenceDebounceNanoseconds: UInt64 = 1_000_000_000
    private static let snapshotBroadcastDebounceNanoseconds: UInt64 = 100_000_000
    private static let indexFileName = "index.json"
    private static let sessionsDirectoryName = "sessions"
    private static let recordsFileName = "records.json"
    private static let legacyFileName = "records.json"

    private let rootDirectoryURL: URL
    private let sessionsDirectoryURL: URL
    private let indexFileURL: URL
    private let legacyFileURL: URL

    private var persistedSessionsByID: [String: ApxyLocalSession]
    private var persistedRecordsBySessionID: [String: [ApxyDebugRecord]]
    private var continuations: [UUID: AsyncStream<ApxyDebugSnapshot>.Continuation]
    private var persistTask: Task<Void, Never>?
    private var broadcastTask: Task<Void, Never>?
    private var hasPendingPersistence = false
    private var hasPendingBroadcast = false
    private var persistWriteCount = 0
    private var dirtySessionIDs: Set<String>
    private var deletedSessionIDs: Set<String>
    private var isIndexDirty = false

    public init(options: ApxyDebugOptions) {
        self.options = options

        let rootDirectoryURL = Self.resolveStoreDirectoryURL(options: options)
        self.rootDirectoryURL = rootDirectoryURL
        self.sessionsDirectoryURL = rootDirectoryURL.appendingPathComponent(Self.sessionsDirectoryName, isDirectory: true)
        self.indexFileURL = sessionsDirectoryURL.appendingPathComponent(Self.indexFileName, isDirectory: false)
        self.legacyFileURL = rootDirectoryURL.appendingPathComponent(Self.legacyFileName, isDirectory: false)

        let loaded = Self.loadPersistedState(
            rootDirectoryURL: rootDirectoryURL,
            sessionsDirectoryURL: self.sessionsDirectoryURL,
            indexFileURL: self.indexFileURL,
            legacyFileURL: self.legacyFileURL
        )

        var sessionsByID = loaded.sessionsByID
        var recordsBySessionID = loaded.recordsBySessionID
        Self.trimPersistedRecordsIfNeeded(
            sessionsByID: &sessionsByID,
            recordsBySessionID: &recordsBySessionID,
            limit: Swift.max(1, options.persistedRecordLimit)
        )

        self.persistedSessionsByID = sessionsByID
        self.persistedRecordsBySessionID = recordsBySessionID
        self.continuations = [:]
        self.dirtySessionIDs = []
        self.deletedSessionIDs = []
        self.broadcastTask = nil
    }

    public func beginSession(
        id: String,
        name: String,
        createdAt: Date,
        sdkClient: SDKClient,
        context: ClientContext,
        serverURL: String?,
        isLiveManaged: Bool
    ) {
        let existing = persistedSessionsByID[id]
        persistedSessionsByID[id] = ApxyLocalSession(
            id: id,
            name: name,
            createdAt: existing?.createdAt ?? createdAt,
            lastEventAt: existing?.lastEventAt ?? createdAt,
            requestCount: existing?.requestCount ?? 0,
            failureCount: existing?.failureCount ?? 0,
            syncState: isLiveManaged ? .liveManaged : .localOnly,
            serverURL: serverURL,
            lastSyncedAt: existing?.lastSyncedAt,
            lastSyncError: nil,
            sdkClient: sdkClient,
            context: context
        )
        markSessionDirty(id)
        broadcastSnapshotNow()
    }

    public func updateSessionContext(
        id: String,
        context: ClientContext,
        serverURL: String?
    ) {
        guard var session = persistedSessionsByID[id] else { return }
        session.context = context
        if let serverURL {
            session.serverURL = serverURL
        }
        persistedSessionsByID[id] = session
        markSessionDirty(id)
        broadcastSnapshotNow()
    }

    public func markSessionSyncState(
        id: String,
        state: ApxyLocalSessionSyncState,
        serverURL: String?,
        errorMessage: String?
    ) {
        guard var session = persistedSessionsByID[id] else { return }
        session.syncState = state
        if let serverURL {
            session.serverURL = serverURL
        }
        switch state {
        case .synced:
            session.lastSyncedAt = Date()
            session.lastSyncError = nil
        case .failed:
            session.lastSyncError = errorMessage
        default:
            if let errorMessage {
                session.lastSyncError = errorMessage
            } else if state != .syncing {
                session.lastSyncError = nil
            }
        }
        persistedSessionsByID[id] = session
        markSessionDirty(id)
        broadcastSnapshotNow()
    }

    public func append(_ record: ApxyDebugRecord) {
        let sessionID = normalizedSessionID(for: record)
        ensureImplicitSessionExists(for: record, sessionID: sessionID)

        var records = persistedRecordsBySessionID[sessionID] ?? []
        records.insert(record, at: 0)
        persistedRecordsBySessionID[sessionID] = records
        recalculateSessionStats(for: sessionID)
        trimPersistedRecordsIfNeeded()
        markSessionDirty(sessionID)
        scheduleBroadcast()
    }

    public func clear() {
        persistTask?.cancel()
        persistTask = nil
        broadcastTask?.cancel()
        broadcastTask = nil
        hasPendingPersistence = false
        hasPendingBroadcast = false
        persistedSessionsByID.removeAll(keepingCapacity: false)
        persistedRecordsBySessionID.removeAll(keepingCapacity: false)
        dirtySessionIDs.removeAll(keepingCapacity: false)
        deletedSessionIDs.removeAll(keepingCapacity: false)
        isIndexDirty = false

        do {
            try FileManager.default.removeItem(at: rootDirectoryURL)
        } catch CocoaError.fileNoSuchFile {
            // Ignore missing stores.
        } catch {
            SDKLogger.warn("ApxyDebugStore failed clearing store: \(error.localizedDescription)")
        }
        broadcastSnapshotNow()
    }

    public func deleteSession(id sessionID: String) {
        guard persistedSessionsByID[sessionID] != nil || persistedRecordsBySessionID[sessionID] != nil else {
            return
        }

        removeSession(sessionID)
        broadcastSnapshotNow()
    }

    public func snapshot() -> ApxyDebugSnapshot {
        makeSnapshot()
    }

    public func localSessions() -> [ApxyLocalSession] {
        persistedSessionsByID.values.sorted { lhs, rhs in
            if lhs.lastEventAt == rhs.lastEventAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.lastEventAt > rhs.lastEventAt
        }
    }

    public func shareableLocalSessions() -> [ApxyLocalSession] {
        localSessions().filter(\.isShareable)
    }

    func loadSessionForSharing(id: String) throws -> SessionSharePayload {
        guard let session = persistedSessionsByID[id] else {
            throw StoreError.sessionNotFound(id)
        }
        guard session.isShareable else {
            throw StoreError.sessionNotShareable(id)
        }
        let records = (persistedRecordsBySessionID[id] ?? []).map(\.networkRecord)
        return SessionSharePayload(session: session, records: records)
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
        let records = Array(
            persistedRecordsBySessionID.values
                .flatMap { $0 }
                .sorted { $0.capturedAt > $1.capturedAt }
                .prefix(max(1, options.memoryRecordLimit))
        )

        let sessions = persistedSessionsByID.values
            .map {
                ApxyDebugSession(
                    id: $0.id,
                    startedAt: $0.createdAt,
                    lastEventAt: $0.lastEventAt,
                    requestCount: $0.requestCount,
                    failureCount: $0.failureCount,
                    syncState: $0.syncState
                )
            }
            .sorted { $0.lastEventAt > $1.lastEventAt }

        return ApxyDebugSnapshot(records: records, sessions: sessions)
    }

    private func ensureImplicitSessionExists(for record: ApxyDebugRecord, sessionID: String) {
        guard persistedSessionsByID[sessionID] == nil else { return }

        let createdAt = record.capturedAt
        persistedSessionsByID[sessionID] = ApxyLocalSession(
            id: sessionID,
            name: Self.defaultSessionName(for: sessionID, createdAt: createdAt),
            createdAt: createdAt,
            lastEventAt: createdAt,
            requestCount: 0,
            failureCount: 0,
            syncState: .localOnly
        )
    }

    private func recalculateSessionStats(for sessionID: String) {
        guard var session = persistedSessionsByID[sessionID] else { return }
        let records = persistedRecordsBySessionID[sessionID] ?? []

        guard let newest = records.first, let oldest = records.last else {
            removeSession(sessionID)
            return
        }

        session.createdAt = oldest.capturedAt
        session.lastEventAt = newest.capturedAt
        session.requestCount = records.count
        session.failureCount = records.reduce(into: 0) { partialResult, record in
            if record.isFailure {
                partialResult += 1
            }
        }
        persistedSessionsByID[sessionID] = session
    }

    private func trimPersistedRecordsIfNeeded() {
        let originalSessionIDs = Set(persistedSessionsByID.keys)
        Self.trimPersistedRecordsIfNeeded(
            sessionsByID: &persistedSessionsByID,
            recordsBySessionID: &persistedRecordsBySessionID,
            limit: Swift.max(1, options.persistedRecordLimit)
        )

        let updatedSessionIDs = Set(persistedSessionsByID.keys)
        let changedSessionIDs = originalSessionIDs.union(updatedSessionIDs)
        for sessionID in changedSessionIDs {
            if originalSessionIDs.contains(sessionID), !updatedSessionIDs.contains(sessionID) {
                deletedSessionIDs.insert(sessionID)
                dirtySessionIDs.remove(sessionID)
                isIndexDirty = true
                hasPendingPersistence = true
                schedulePersist()
                continue
            }
            if updatedSessionIDs.contains(sessionID) {
                markSessionDirty(sessionID)
            }
        }
    }

    private var totalPersistedRecordCount: Int {
        persistedRecordsBySessionID.values.reduce(into: 0) { partialResult, records in
            partialResult += records.count
        }
    }

    private func oldestSessionID() -> String? {
        persistedRecordsBySessionID
            .compactMap { sessionID, records in
                records.last.map { (sessionID, $0.capturedAt) }
            }
            .min { lhs, rhs in lhs.1 < rhs.1 }
            .map(\.0)
    }

    private func markSessionDirty(_ sessionID: String) {
        dirtySessionIDs.insert(sessionID)
        deletedSessionIDs.remove(sessionID)
        isIndexDirty = true
        hasPendingPersistence = true
        schedulePersist()
    }

    private func removeSession(_ sessionID: String) {
        persistedSessionsByID.removeValue(forKey: sessionID)
        persistedRecordsBySessionID.removeValue(forKey: sessionID)
        deletedSessionIDs.insert(sessionID)
        dirtySessionIDs.remove(sessionID)
        isIndexDirty = true
        hasPendingPersistence = true
        schedulePersist()
    }

    private func schedulePersist() {
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

    private func scheduleBroadcast() {
        hasPendingBroadcast = true
        guard broadcastTask == nil else { return }

        broadcastTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.snapshotBroadcastDebounceNanoseconds)
            } catch {
                return
            }

            await self?.completeScheduledBroadcast()
        }
    }

    private func completeScheduledBroadcast() async {
        broadcastTask = nil
        guard hasPendingBroadcast else { return }
        hasPendingBroadcast = false
        broadcastSnapshot()
    }

    private func broadcastSnapshotNow() {
        broadcastTask?.cancel()
        broadcastTask = nil
        hasPendingBroadcast = false
        broadcastSnapshot()
    }

    private func flushPersistenceIfNeeded() {
        guard hasPendingPersistence else { return }

        let dirtySessionIDs = self.dirtySessionIDs
        let deletedSessionIDs = self.deletedSessionIDs
        let shouldWriteIndex = isIndexDirty
        let sessions = persistedSessionsByID.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt < rhs.createdAt
        }

        do {
            try FileManager.default.createDirectory(
                at: sessionsDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if shouldWriteIndex {
                let indexData = try encoder.encode(PersistedIndex(sessions: sessions))
                try indexData.write(to: indexFileURL, options: [.atomic])
            }

            for sessionID in dirtySessionIDs {
                let sessionDirectoryURL = Self.sessionDirectoryURL(
                    baseURL: sessionsDirectoryURL,
                    sessionID: sessionID
                )
                try FileManager.default.createDirectory(
                    at: sessionDirectoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                let recordsFileURL = sessionDirectoryURL.appendingPathComponent(Self.recordsFileName, isDirectory: false)
                let records = persistedRecordsBySessionID[sessionID] ?? []
                let recordData = try encoder.encode(records)
                try recordData.write(to: recordsFileURL, options: [.atomic])
            }

            for sessionID in deletedSessionIDs {
                let sessionDirectoryURL = Self.sessionDirectoryURL(
                    baseURL: sessionsDirectoryURL,
                    sessionID: sessionID
                )
                do {
                    try FileManager.default.removeItem(at: sessionDirectoryURL)
                } catch CocoaError.fileNoSuchFile {
                }
            }

            do {
                try FileManager.default.removeItem(at: legacyFileURL)
            } catch CocoaError.fileNoSuchFile {
            }

            hasPendingPersistence = false
            self.dirtySessionIDs.subtract(dirtySessionIDs)
            self.deletedSessionIDs.subtract(deletedSessionIDs)
            if shouldWriteIndex {
                isIndexDirty = false
            }
            persistWriteCount += 1
        } catch {
            hasPendingPersistence = true
            self.dirtySessionIDs.formUnion(dirtySessionIDs)
            self.deletedSessionIDs.formUnion(deletedSessionIDs)
            if shouldWriteIndex {
                isIndexDirty = true
            }
            SDKLogger.warn("ApxyDebugStore failed persisting store: \(error.localizedDescription)")
        }
    }

    private func broadcastSnapshot() {
        let snapshot = makeSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func normalizedSessionID(for record: ApxyDebugRecord) -> String {
        guard let sessionID = record.sessionID, !sessionID.isEmpty else {
            return "unsessioned"
        }
        return sessionID
    }

    private static func resolveStoreDirectoryURL(options: ApxyDebugOptions) -> URL {
        if let storeURL = options.storeURL {
            if storeURL.hasDirectoryPath || storeURL.pathExtension.isEmpty {
                return storeURL
            }
            return storeURL.deletingLastPathComponent()
        }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL
            .appendingPathComponent("ApxyCore", isDirectory: true)
            .appendingPathComponent("DebugConsole", isDirectory: true)
    }

    private static func sessionDirectoryURL(baseURL: URL, sessionID: String) -> URL {
        baseURL.appendingPathComponent(sessionID, isDirectory: true)
    }

    private static func defaultSessionName(for sessionID: String, createdAt: Date) -> String {
        if sessionID == "unsessioned" {
            return "Unsessioned"
        }
        return "SDK \(timestampFormatter.string(from: createdAt))"
    }

    private static func loadPersistedState(
        rootDirectoryURL: URL,
        sessionsDirectoryURL: URL,
        indexFileURL: URL,
        legacyFileURL: URL
    ) -> (
        sessionsByID: [String: ApxyLocalSession],
        recordsBySessionID: [String: [ApxyDebugRecord]]
    ) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let indexData = try? Data(contentsOf: indexFileURL),
              let index = try? decoder.decode(PersistedIndex.self, from: indexData) else {
            return loadLegacyState(legacyFileURL: legacyFileURL)
        }

        var sessionsByID: [String: ApxyLocalSession] = [:]
        var recordsBySessionID: [String: [ApxyDebugRecord]] = [:]

        for session in index.sessions {
            sessionsByID[session.id] = session

            let recordsFileURL = sessionDirectoryURL(baseURL: sessionsDirectoryURL, sessionID: session.id)
                .appendingPathComponent(Self.recordsFileName, isDirectory: false)
            guard let recordData = try? Data(contentsOf: recordsFileURL),
                  let records = try? decoder.decode([ApxyDebugRecord].self, from: recordData) else {
                recordsBySessionID[session.id] = []
                continue
            }
            recordsBySessionID[session.id] = records.sorted { $0.capturedAt > $1.capturedAt }
        }

        return (sessionsByID, recordsBySessionID)
    }

    private static func loadLegacyState(
        legacyFileURL: URL
    ) -> (
        sessionsByID: [String: ApxyLocalSession],
        recordsBySessionID: [String: [ApxyDebugRecord]]
    ) {
        guard let data = try? Data(contentsOf: legacyFileURL) else {
            return ([:], [:])
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let records = try? decoder.decode([ApxyDebugRecord].self, from: data) else {
            return ([:], [:])
        }

        let sortedRecords = records.sorted { $0.capturedAt > $1.capturedAt }
        var sessionsByID: [String: ApxyLocalSession] = [:]
        var recordsBySessionID: [String: [ApxyDebugRecord]] = [:]

        for record in sortedRecords {
            let sessionID = record.sessionID?.isEmpty == false ? record.sessionID! : "unsessioned"
            recordsBySessionID[sessionID, default: []].append(record)
        }

        for (sessionID, sessionRecords) in recordsBySessionID {
            guard let newest = sessionRecords.first, let oldest = sessionRecords.last else { continue }
            sessionsByID[sessionID] = ApxyLocalSession(
                id: sessionID,
                name: defaultSessionName(for: sessionID, createdAt: oldest.capturedAt),
                createdAt: oldest.capturedAt,
                lastEventAt: newest.capturedAt,
                requestCount: sessionRecords.count,
                failureCount: sessionRecords.reduce(into: 0) { partialResult, record in
                    if record.isFailure {
                        partialResult += 1
                    }
                },
                syncState: .localOnly
            )
        }

        return (sessionsByID, recordsBySessionID)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static func trimPersistedRecordsIfNeeded(
        sessionsByID: inout [String: ApxyLocalSession],
        recordsBySessionID: inout [String: [ApxyDebugRecord]],
        limit: Int
    ) {
        func recalculateSessionStats(_ sessionID: String) {
            guard var session = sessionsByID[sessionID] else { return }
            let records = recordsBySessionID[sessionID] ?? []

            guard let newest = records.first, let oldest = records.last else {
                sessionsByID.removeValue(forKey: sessionID)
                recordsBySessionID.removeValue(forKey: sessionID)
                return
            }

            session.createdAt = oldest.capturedAt
            session.lastEventAt = newest.capturedAt
            session.requestCount = records.count
            session.failureCount = records.reduce(into: 0) { partialResult, record in
                if record.isFailure {
                    partialResult += 1
                }
            }
            sessionsByID[sessionID] = session
        }

        func totalRecordCount() -> Int {
            recordsBySessionID.values.reduce(into: 0) { partialResult, records in
                partialResult += records.count
            }
        }

        func oldestSessionID() -> String? {
            recordsBySessionID
                .compactMap { sessionID, records in
                    records.last.map { (sessionID, $0.capturedAt) }
                }
                .min { lhs, rhs in lhs.1 < rhs.1 }
                .map(\.0)
        }

        while totalRecordCount() > limit {
            guard let sessionID = oldestSessionID() else { break }
            guard var records = recordsBySessionID[sessionID], !records.isEmpty else { break }
            _ = records.removeLast()
            if records.isEmpty {
                recordsBySessionID.removeValue(forKey: sessionID)
            } else {
                recordsBySessionID[sessionID] = records
            }
            recalculateSessionStats(sessionID)
        }
    }
}

private extension ApxyDebugRecord {
    var networkRecord: NetworkRecord {
        NetworkRecord(
            id: id,
            timestamp: capturedAt,
            method: request.method,
            url: request.url,
            host: request.host,
            path: request.path,
            requestHeaders: request.headers,
            requestBody: request.body,
            requestBodySource: nil,
            requestBodySize: request.bodySize,
            requestContentType: request.contentType,
            finalURL: request.currentURL,
            finalHost: request.currentHost,
            finalPath: request.currentPath,
            finalRequestHeaders: request.currentHeaders,
            statusCode: response?.statusCode ?? (error != nil ? -1 : 0),
            responseHeaders: response?.headers,
            responseBody: response?.body,
            responseBodySize: response?.bodySize,
            responseContentType: response?.contentType,
            redirectCount: redirectCount,
            requestHeaderBytesSent: transfer.requestHeaderBytesSent,
            requestBodyBytesBeforeEncoding: transfer.requestBodyBytesBeforeEncoding,
            requestBodyBytesSent: transfer.requestBodyBytesSent,
            responseHeaderBytesReceived: transfer.responseHeaderBytesReceived,
            responseBodyBytesReceived: transfer.responseBodyBytesReceived,
            responseBodyBytesAfterDecoding: transfer.responseBodyBytesAfterDecoding,
            duration: Int64(duration * 1_000_000_000),
            tls: isTLS,
            mocked: isMocked,
            sessionID: sessionID
        )
    }
}

import Foundation

/// Sync status for a persisted local SDK session on device.
public enum ApxyLocalSessionSyncState: String, Codable, Sendable {
    case localOnly
    case liveManaged
    case syncing
    case synced
    case failed
}

/// Persisted local session metadata used for on-device review and later sharing.
public struct ApxyLocalSession: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var createdAt: Date
    public var lastEventAt: Date
    public var requestCount: Int
    public var failureCount: Int
    public var syncState: ApxyLocalSessionSyncState
    public var serverURL: String?
    public var lastSyncedAt: Date?
    public var lastSyncError: String?
    public var sdkClient: SDKClient?
    public var context: ClientContext?

    public init(
        id: String,
        name: String,
        createdAt: Date,
        lastEventAt: Date,
        requestCount: Int,
        failureCount: Int,
        syncState: ApxyLocalSessionSyncState,
        serverURL: String? = nil,
        lastSyncedAt: Date? = nil,
        lastSyncError: String? = nil,
        sdkClient: SDKClient? = nil,
        context: ClientContext? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastEventAt = lastEventAt
        self.requestCount = requestCount
        self.failureCount = failureCount
        self.syncState = syncState
        self.serverURL = serverURL
        self.lastSyncedAt = lastSyncedAt
        self.lastSyncError = lastSyncError
        self.sdkClient = sdkClient
        self.context = context
    }

    public var isShareable: Bool {
        switch syncState {
        case .localOnly, .synced, .failed:
            return true
        case .liveManaged, .syncing:
            return false
        }
    }
}

import Foundation

/// Configuration for the embedded local debug console.
public struct ApxyDebugOptions: Sendable, Equatable {
    /// Enables local recording for the embedded debug console.
    public var isEnabled: Bool
    /// Maximum number of records retained in memory for fast UI updates.
    public var memoryRecordLimit: Int
    /// Maximum number of records retained on disk across app launches.
    public var persistedRecordLimit: Int
    /// Optional custom persistence URL. Defaults to the app support directory.
    public var storeURL: URL?

    public init(
        isEnabled: Bool,
        memoryRecordLimit: Int = 200,
        persistedRecordLimit: Int = 2_000,
        storeURL: URL? = nil
    ) {
        self.isEnabled = isEnabled
        self.memoryRecordLimit = memoryRecordLimit
        self.persistedRecordLimit = persistedRecordLimit
        self.storeURL = storeURL
    }

    public static let enabled = ApxyDebugOptions(isEnabled: true)
    public static let disabled = ApxyDebugOptions(isEnabled: false)
}

import Foundation

/// Mirrors the Go `SDKClient` domain struct registered with APXY Core.
public struct SDKClient: Codable, Sendable {
    public var id: String
    public var platform: String
    public var deviceModel: String
    public var osName: String
    public var osVersion: String
    public var appBundleID: String
    public var appVersion: String
    public var appBuild: String
    public var sdkVersion: String
    public var firstSeenAt: Date
    public var lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case id, platform
        case deviceModel = "device_model"
        case osName = "os_name"
        case osVersion = "os_version"
        case appBundleID = "app_bundle_id"
        case appVersion = "app_version"
        case appBuild = "app_build"
        case sdkVersion = "sdk_version"
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
    }
}

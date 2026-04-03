import Foundation
import CryptoKit

/// Builds and hashes a deterministic `SDKClient` from static device/app info.
/// The same device running the same app version always produces the same `id`.
enum ClientIdentity {
    static let sdkVersion = "0.1.0"

    static func build() -> SDKClient {
        let now = Date()
        return SDKClient(
            id: makeID(),
            platform: DeviceInfo.platform,
            deviceModel: DeviceInfo.model,
            osName: DeviceInfo.osName,
            osVersion: DeviceInfo.osVersion,
            appBundleID: AppInfo.bundleID,
            appVersion: AppInfo.version,
            appBuild: AppInfo.build,
            sdkVersion: sdkVersion,
            firstSeenAt: now,
            lastSeenAt: now
        )
    }

    private static func makeID() -> String {
        let raw = [
            DeviceInfo.platform,
            DeviceInfo.model,
            DeviceInfo.osVersion,
            AppInfo.bundleID,
            AppInfo.version,
        ].joined(separator: ":")

        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

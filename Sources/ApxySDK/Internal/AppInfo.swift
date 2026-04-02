import Foundation

/// Reads app identity information from the main bundle.
enum AppInfo {
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

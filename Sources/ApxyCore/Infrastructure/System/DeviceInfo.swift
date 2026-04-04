#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Foundation

/// Collects static device and OS information at SDK startup.
enum DeviceInfo {

    static var model: String {
#if canImport(UIKit)
        return UIDevice.current.model
#elseif canImport(AppKit)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machineRaw = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machineRaw, &size, nil, 0)
        let bytes = machineRaw.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
        return String(decoding: bytes, as: UTF8.self)
#else
        return "Unknown"
#endif
    }

    static var osName: String {
#if os(iOS)
        return "iOS"
#elseif os(macOS)
        return "macOS"
#elseif os(tvOS)
        return "tvOS"
#elseif os(watchOS)
        return "watchOS"
#else
        return "Unknown"
#endif
    }

    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static var platform: String {
#if os(iOS)
        return "ios"
#elseif os(macOS)
        return "macos"
#elseif os(tvOS)
        return "tvos"
#elseif os(watchOS)
        return "watchos"
#else
        return "unknown"
#endif
    }
}

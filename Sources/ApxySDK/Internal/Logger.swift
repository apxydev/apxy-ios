import Foundation
import os.log

/// SDK-internal logger that respects the configured `ApxyLogLevel`.
/// Format: `[ApxySDK] [level] [Source:line] message`
enum SDKLogger {
    private static let subsystem = "dev.apxy.sdk"
    private static let log = OSLog(subsystem: subsystem, category: "ApxySDK")
    private static let levelLock = NSLock()
    nonisolated(unsafe) private static var levelStorage: ApxyLogLevel = .warning

    static var level: ApxyLogLevel {
        get {
            levelLock.lock()
            defer { levelLock.unlock() }
            return levelStorage
        }
        set {
            levelLock.lock()
            levelStorage = newValue
            levelLock.unlock()
        }
    }

    private static func sourceLabel(file: StaticString, line: UInt) -> String {
        let id = String(describing: file)
        let base = (id as NSString).lastPathComponent
        let stem = base.replacingOccurrences(of: ".swift", with: "")
        return "\(stem):\(line)"
    }

    private static func format(level: String, file: StaticString, line: UInt, message: String) -> String {
        "[ApxySDK] [\(level)] [\(sourceLabel(file: file, line: line))] \(message)"
    }

    static func debug(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard level.rawValue >= ApxyLogLevel.debug.rawValue else { return }
        let out = format(level: "debug", file: file, line: line, message: message())
        os_log("%{public}@", log: log, type: .debug, out)
    }

    static func warn(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard level.rawValue >= ApxyLogLevel.warning.rawValue else { return }
        let out = format(level: "warning", file: file, line: line, message: message())
        os_log("%{public}@", log: log, type: .default, out)
    }

    static func error(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard level != .none else { return }
        let out = format(level: "error", file: file, line: line, message: message())
        os_log("%{public}@", log: log, type: .error, out)
    }
}

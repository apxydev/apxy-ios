import Foundation
import ApxyCore

enum ApxyDebugConsoleExporter {
    static func write(records: [ApxyDebugRecord]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(records)
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("apxy-debug-\(UUID().uuidString).json")
        try data.write(to: url, options: [.atomic])
        return url
    }
}

import Foundation
import ApxyCore

enum ApxyDebugRecordExportFormatter {
    static func jsonString(for record: ApxyDebugRecord) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(record) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

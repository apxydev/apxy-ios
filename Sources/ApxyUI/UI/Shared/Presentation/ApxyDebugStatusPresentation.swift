import SwiftUI
import ApxyCore

struct ApxyDebugStatusPresentation {
    let color: Color
    let iconName: String

    static func from(record: ApxyDebugRecord) -> ApxyDebugStatusPresentation {
        if record.error != nil {
            return ApxyDebugStatusPresentation(color: .red, iconName: "xmark.circle.fill")
        }
        if let statusCode = record.response?.statusCode {
            switch statusCode {
            case 200..<400:
                return ApxyDebugStatusPresentation(color: .green, iconName: "checkmark.circle.fill")
            case 400...:
                return ApxyDebugStatusPresentation(color: .red, iconName: "exclamationmark.triangle.fill")
            default:
                return ApxyDebugStatusPresentation(color: .orange, iconName: "clock.fill")
            }
        }
        return ApxyDebugStatusPresentation(color: .orange, iconName: "clock.fill")
    }
}

import SwiftUI
import ApxyCore

struct ApxyDebugStatusPresentation {
    let tone: ApxyDebugThemeTone
    let iconName: String

    func color(in theme: ApxyDebugThemePalette) -> Color {
        tone.color(in: theme)
    }

    static func from(record: ApxyDebugRecord) -> ApxyDebugStatusPresentation {
        if record.error != nil {
            return ApxyDebugStatusPresentation(tone: .error, iconName: "xmark.circle.fill")
        }
        if let statusCode = record.response?.statusCode {
            switch statusCode {
            case 200..<400:
                return ApxyDebugStatusPresentation(tone: .success, iconName: "checkmark.circle.fill")
            case 400...:
                return ApxyDebugStatusPresentation(tone: .error, iconName: "exclamationmark.triangle.fill")
            default:
                return ApxyDebugStatusPresentation(tone: .warning, iconName: "clock.fill")
            }
        }
        return ApxyDebugStatusPresentation(tone: .warning, iconName: "clock.fill")
    }
}

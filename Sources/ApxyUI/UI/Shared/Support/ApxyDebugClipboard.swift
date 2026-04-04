import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum ApxyDebugClipboard {
    static func copy(_ value: String) {
#if os(iOS)
        UIPasteboard.general.string = value
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
#endif
    }
}

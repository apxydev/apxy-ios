import SwiftUI

enum ApxyDebugChrome {
    static let compactRowSpacing: CGFloat = 4
    static let regularRowSpacing: CGFloat = 8
    static let iconColumnWidth: CGFloat = 27
    static let controlCornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 14
    static let contentPadding: CGFloat = 14
    static let screenPadding: CGFloat = 16
    static let listRowInset: CGFloat = 16
    static let cardRowHorizontalPadding: CGFloat = contentPadding
    static let cardRowVerticalPadding: CGFloat = 10

    static func subtleFill(in theme: ApxyDebugThemePalette) -> Color {
        theme.surface
    }

    static func elevatedFill(in theme: ApxyDebugThemePalette) -> Color {
        theme.surfaceElevated
    }

    static func terminalFill(in theme: ApxyDebugThemePalette) -> Color {
        theme.terminalSurface
    }

    static func selectedFill(in theme: ApxyDebugThemePalette) -> Color {
        theme.selection
    }

    static func subtleStroke(in theme: ApxyDebugThemePalette) -> Color {
        theme.border
    }
}

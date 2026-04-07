import SwiftUI

struct ApxyDebugThemePalette {
    let canvas: Color
    let canvasSecondary: Color
    let surface: Color
    let surfaceElevated: Color
    let terminalSurface: Color
    let terminalBar: Color
    let border: Color
    let borderStrong: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let accentHover: Color
    let accentSoft: Color
    let accentBorder: Color
    let selection: Color
    let success: Color
    let warning: Color
    let error: Color
    let shadow: Color
}

enum ApxyDebugThemeTone: Equatable {
    case accent
    case success
    case warning
    case error
    case muted

    func color(in theme: ApxyDebugThemePalette) -> Color {
        switch self {
        case .accent:
            theme.accent
        case .success:
            theme.success
        case .warning:
            theme.warning
        case .error:
            theme.error
        case .muted:
            theme.textSecondary
        }
    }
}

enum ApxyDebugTheme {
    struct Tokens: Equatable {
        let backgroundPrimary: UInt32
        let backgroundSecondary: UInt32
        let backgroundElevated: UInt32
        let backgroundTerminal: UInt32
        let terminalBar: UInt32
        let textPrimary: UInt32
        let textSecondary: UInt32
        let textMuted: UInt32
        let accent: UInt32
        let accentHover: UInt32
        let border: UInt32
        let accentBorder: UInt32
        let success: UInt32
        let warning: UInt32
        let error: UInt32
    }

    static func tokens(for colorScheme: ColorScheme) -> Tokens {
        switch colorScheme {
        case .dark:
            Tokens(
                backgroundPrimary: 0x0A0A0A,
                backgroundSecondary: 0x111111,
                backgroundElevated: 0x141414,
                backgroundTerminal: 0x141414,
                terminalBar: 0x0F0F0F,
                textPrimary: 0xFAFAFA,
                textSecondary: 0xA3A3A3,
                textMuted: 0x737373,
                accent: 0x3B82F6,
                accentHover: 0x2563EB,
                border: 0x262626,
                accentBorder: 0x60A5FA,
                success: 0x22C55E,
                warning: 0xF59E0B,
                error: 0xEF4444
            )
        default:
            Tokens(
                backgroundPrimary: 0xFFFFFF,
                backgroundSecondary: 0xF5F4ED,
                backgroundElevated: 0xFAF9F5,
                backgroundTerminal: 0x1D1A17,
                terminalBar: 0x161412,
                textPrimary: 0x141413,
                textSecondary: 0x3D3D3A,
                textMuted: 0x73726C,
                accent: 0xD97757,
                accentHover: 0xC56A4C,
                border: 0xE5DFD3,
                accentBorder: 0xEBC1B1,
                success: 0x15803D,
                warning: 0xB45309,
                error: 0xDC2626
            )
        }
    }

    static func palette(for colorScheme: ColorScheme) -> ApxyDebugThemePalette {
        tokens(for: colorScheme).palette
    }
}

private extension ApxyDebugTheme.Tokens {
    var palette: ApxyDebugThemePalette {
        let accentColor = Color(apxyHex: accent)

        return ApxyDebugThemePalette(
            canvas: Color(apxyHex: backgroundPrimary),
            canvasSecondary: Color(apxyHex: backgroundSecondary),
            surface: Color(apxyHex: backgroundSecondary),
            surfaceElevated: Color(apxyHex: backgroundElevated),
            terminalSurface: Color(apxyHex: backgroundTerminal),
            terminalBar: Color(apxyHex: terminalBar),
            border: Color(apxyHex: border),
            borderStrong: Color(apxyHex: accentBorder),
            textPrimary: Color(apxyHex: textPrimary),
            textSecondary: Color(apxyHex: textSecondary),
            textMuted: Color(apxyHex: textMuted),
            accent: accentColor,
            accentHover: Color(apxyHex: accentHover),
            accentSoft: accentColor.opacity(0.12),
            accentBorder: Color(apxyHex: accentBorder),
            selection: accentColor.opacity(0.16),
            success: Color(apxyHex: success),
            warning: Color(apxyHex: warning),
            error: Color(apxyHex: error),
            shadow: Color.black.opacity(0.16)
        )
    }
}

private extension Color {
    init(apxyHex hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

import SwiftUI

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
enum ApxyDebugPreviewPlatform: String {
    case iOS
    case macOS
}

@available(iOS 17.0, macOS 14.0, *)
private extension ApxyDebugPreviewPlatform {
    func componentSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 420, height: 220)
        case .macOS:
            CGSize(width: 520, height: 220)
        }
    }

    func controlSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 360, height: 160)
        case .macOS:
            CGSize(width: 440, height: 160)
        }
    }

    func rowSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 420, height: 140)
        case .macOS:
            CGSize(width: 560, height: 140)
        }
    }

    func listSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 430, height: 620)
        case .macOS:
            CGSize(width: 560, height: 620)
        }
    }

    func detailSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 430, height: 760)
        case .macOS:
            CGSize(width: 980, height: 720)
        }
    }

    func screenSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 430, height: 932)
        case .macOS:
            CGSize(width: 1100, height: 720)
        }
    }

    func compactScreenSize() -> CGSize {
        switch self {
        case .iOS:
            CGSize(width: 430, height: 320)
        case .macOS:
            CGSize(width: 520, height: 320)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension View {
    func apxyPreviewComponent(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.componentSize()
        return frame(width: size.width, height: size.height)
    }

    func apxyPreviewControl(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.controlSize()
        return frame(width: size.width, height: size.height)
    }

    func apxyPreviewRow(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.rowSize()
        return frame(width: size.width, height: size.height)
    }

    func apxyPreviewList(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.listSize()
        return frame(width: size.width, height: size.height)
    }

    func apxyPreviewDetail(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.detailSize()
        return frame(width: size.width, height: size.height)
    }

    func apxyPreviewScreen(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.screenSize()
        return frame(width: size.width, height: size.height)
    }

    func apxyPreviewCompactScreen(_ platform: ApxyDebugPreviewPlatform) -> some View {
        let size = platform.compactScreenSize()
        return frame(width: size.width, height: size.height)
    }
}
#endif

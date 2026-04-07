import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugToastView: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
            Text(message)
                .font(.subheadline.bold())
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surfaceElevated, in: Capsule())
        .overlay {
            Capsule()
                .stroke(theme.border)
        }
        .shadow(color: theme.shadow, radius: 10, y: 5)
        .accessibilityAddTraits(.isStaticText)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Toast iOS") {
    ZStack {
        Color.clear
        ApxyDebugToastView(message: "cURL copied")
    }
    .padding()
    .apxyPreviewComponent(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Toast macOS") {
    ZStack {
        Color.clear
        ApxyDebugToastView(message: "cURL copied")
    }
    .padding()
    .apxyPreviewComponent(.macOS)
}
#endif

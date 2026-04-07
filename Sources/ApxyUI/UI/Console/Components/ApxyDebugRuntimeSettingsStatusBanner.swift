import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRuntimeSettingsStatusBanner: View {
    let message: String
    let kind: ApxyDebugRuntimeSettingsViewModel.StatusKind

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)
        let tint = tintColor(in: theme)

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.28))
        }
        .accessibilityAddTraits(.isStaticText)
    }

    private var symbolName: String {
        switch kind {
        case .success:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private func tintColor(in theme: ApxyDebugThemePalette) -> Color {
        switch kind {
        case .success:
            theme.success
        case .error:
            theme.error
        }
    }
}

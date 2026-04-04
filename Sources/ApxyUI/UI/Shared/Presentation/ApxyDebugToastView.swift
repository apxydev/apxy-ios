import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
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

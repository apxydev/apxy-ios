import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugPlaceholderPanel: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ApxyDebugSurfaceCard {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Placeholder Panel") {
    ApxyDebugPlaceholderPanel(
        title: "No Request Selected",
        systemImage: "point.3.connected.trianglepath.dotted",
        message: "Pick a request from the list to inspect headers, body, cookies, and timing."
    )
    .padding()
}
#endif

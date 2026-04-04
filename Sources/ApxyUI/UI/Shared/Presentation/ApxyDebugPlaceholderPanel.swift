import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugPlaceholderPanel: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        Group {
            if #available(iOS 17.0, macOS 14.0, *) {
                ContentUnavailableView {
                    Label(title, systemImage: systemImage)
                } description: {
                    Text(message)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Placeholder Panel iOS") {
    ApxyDebugPlaceholderPanel(
        title: "No Request Selected",
        systemImage: "point.3.connected.trianglepath.dotted",
        message: "Pick a request from the list to inspect headers, body, cookies, and timing."
    )
    .padding()
    .apxyPreviewComponent(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Placeholder Panel macOS") {
    ApxyDebugPlaceholderPanel(
        title: "No Request Selected",
        systemImage: "point.3.connected.trianglepath.dotted",
        message: "Pick a request from the list to inspect headers, body, cookies, and timing."
    )
    .padding()
    .apxyPreviewComponent(.macOS)
}
#endif

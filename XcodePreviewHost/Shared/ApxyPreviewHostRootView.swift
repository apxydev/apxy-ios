import SwiftUI
import ApxyUI

struct ApxyPreviewHostRootView: View {
    @State private var didBootstrap = false

    var body: some View {
        Group {
            if didBootstrap {
                ApxyDebugConsoleContainer()
            } else {
                ProgressView("Loading Mock Traffic…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard !didBootstrap else { return }
            await ApxyPreviewHostBootstrap.startIfNeeded()
            didBootstrap = true
        }
    }
}

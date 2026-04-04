import SwiftUI

@main
struct ApxyPreviewHostmacOSApp: App {
    var body: some Scene {
        WindowGroup {
            ApxyPreviewHostRootView()
                .frame(minWidth: 960, minHeight: 680)
        }
    }
}

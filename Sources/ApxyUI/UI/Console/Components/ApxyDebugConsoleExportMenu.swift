import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugConsoleExportMenu: View {
    let exportURL: URL?
    let onPrepareExport: () -> Void

    var body: some View {
        Menu {
            Button("Prepare JSON Export", action: onPrepareExport)
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share Latest Export", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Export Menu iOS") {
    ApxyDebugConsoleExportMenu(
        exportURL: ApxyDebugPreviewFixtures.exportURL,
        onPrepareExport: {}
    )
    .padding()
    .apxyPreviewControl(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Export Menu macOS") {
    ApxyDebugConsoleExportMenu(
        exportURL: ApxyDebugPreviewFixtures.exportURL,
        onPrepareExport: {}
    )
    .padding()
    .apxyPreviewControl(.macOS)
}
#endif

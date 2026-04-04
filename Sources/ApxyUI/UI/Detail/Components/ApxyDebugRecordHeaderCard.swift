import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRecordHeaderCard: View {
    let method: String
    let isMocked: Bool
    let isTLS: Bool
    let host: String
    let path: String
    let statusText: String
    let statusSymbol: String
    let statusColor: Color
    let durationText: String
    let url: String

    var body: some View {
        ApxyDebugSurfaceCard(style: .plain) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ApxyDebugStatusDot(color: statusColor)

                    Label(statusText, systemImage: statusSymbol)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)

                    Spacer(minLength: 12)

                    Text(durationText)
                        .font(.system(.caption, design: .monospaced).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    capsuleLabel(method, tint: .accentColor)
                    if isMocked {
                        capsuleLabel("Mock", tint: .secondary)
                    }
                    if isTLS {
                        capsuleLabel("TLS", tint: .green)
                    }
                    Spacer()
                }

                Text(host)
                    .font(.title3.bold())
                    .lineLimit(2)

                Text(path)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Divider()
                    .overlay(ApxyDebugChrome.subtleStroke)

                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func capsuleLabel(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Header Card iOS") {
    let record = ApxyDebugPreviewFixtures.failedRecord
    let presentation = ApxyDebugStatusPresentation.from(record: record)

    return ApxyDebugRecordHeaderCard(
        method: record.request.method,
        isMocked: record.isMocked,
        isTLS: record.isTLS,
        host: record.request.currentHost ?? record.request.host,
        path: record.request.currentPath ?? record.request.path,
        statusText: record.response.map { "\($0.statusCode)" } ?? "Pending",
        statusSymbol: presentation.iconName,
        statusColor: presentation.color,
        durationText: ApxyDebugValueFormatters.duration(record.duration),
        url: record.request.currentURL ?? record.request.url
    )
    .padding()
    .apxyPreviewComponent(.iOS)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Header Card macOS") {
    let record = ApxyDebugPreviewFixtures.failedRecord
    let presentation = ApxyDebugStatusPresentation.from(record: record)

    return ApxyDebugRecordHeaderCard(
        method: record.request.method,
        isMocked: record.isMocked,
        isTLS: record.isTLS,
        host: record.request.currentHost ?? record.request.host,
        path: record.request.currentPath ?? record.request.path,
        statusText: record.response.map { "\($0.statusCode)" } ?? "Pending",
        statusSymbol: presentation.iconName,
        statusColor: presentation.color,
        durationText: ApxyDebugValueFormatters.duration(record.duration),
        url: record.request.currentURL ?? record.request.url
    )
    .padding()
    .apxyPreviewComponent(.macOS)
}
#endif

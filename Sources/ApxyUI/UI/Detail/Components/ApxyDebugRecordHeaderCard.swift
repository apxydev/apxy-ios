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
        ApxyDebugSurfaceCard(style: .material, topAccent: statusColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            capsuleLabel(method, tint: .accentColor)
                            if isMocked {
                                capsuleLabel("Mock", tint: .secondary)
                            }
                            if isTLS {
                                capsuleLabel("TLS", tint: .green)
                            }
                        }

                        Text(host)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)

                        Text(path)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        Label(statusText, systemImage: statusSymbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(statusColor, in: Capsule())

                        Text(durationText)
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }

                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func capsuleLabel(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Record Header Card") {
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
}
#endif

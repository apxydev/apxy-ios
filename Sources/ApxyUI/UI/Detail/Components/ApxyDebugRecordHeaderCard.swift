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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        ApxyDebugSurfaceCard(style: .elevated, topAccent: statusColor) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: statusSymbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 44, height: 44)
                        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(host)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(2)

                        Text(path)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                ViewThatFits {
                    HStack(spacing: 8) {
                        headerBadge(title: statusText, systemImage: statusSymbol, color: statusColor)
                        capsuleLabel(method, tone: .accent)
                        if isMocked {
                            capsuleLabel("Mocked", tone: .warning)
                        }
                        capsuleLabel(isTLS ? "TLS" : "Standard", tone: isTLS ? .success : .muted)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        headerBadge(title: statusText, systemImage: statusSymbol, color: statusColor)
                        HStack(spacing: 8) {
                            capsuleLabel(method, tone: .accent)
                            if isMocked {
                                capsuleLabel("Mocked", tone: .warning)
                            }
                            capsuleLabel(isTLS ? "TLS" : "Standard", tone: isTLS ? .success : .muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(summaryDescription)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits {
                    HStack(spacing: 12) {
                        summaryMetric(
                            title: "Method",
                            value: method,
                            systemImage: "arrow.left.arrow.right",
                            tint: theme.accent,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Duration",
                            value: durationText,
                            systemImage: "timer",
                            tint: theme.warning,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Transport",
                            value: transportSummary,
                            systemImage: isTLS ? "lock.shield.fill" : "network",
                            tint: isTLS ? theme.success : theme.textSecondary,
                            theme: theme
                        )
                    }

                    VStack(spacing: 12) {
                        summaryMetric(
                            title: "Method",
                            value: method,
                            systemImage: "arrow.left.arrow.right",
                            tint: theme.accent,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Duration",
                            value: durationText,
                            systemImage: "timer",
                            tint: theme.warning,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Transport",
                            value: transportSummary,
                            systemImage: isTLS ? "lock.shield.fill" : "network",
                            tint: isTLS ? theme.success : theme.textSecondary,
                            theme: theme
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Request URL", systemImage: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)

                    Text(url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.border)
                        }
                }
            }
        }
    }

    private var summaryDescription: String {
        let mockedSummary = isMocked ? "Mocked response." : "Live network request."
        return "\(mockedSummary) Completed with status \(statusText) in \(durationText)."
    }

    private var transportSummary: String {
        if isMocked {
            return isTLS ? "Mock + TLS" : "Mock + Standard"
        }

        return isTLS ? "TLS" : "Standard"
    }

    private func headerBadge(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.28))
            }
    }

    private func summaryMetric(
        title: String,
        value: String,
        systemImage: String,
        tint: Color,
        theme: ApxyDebugThemePalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border)
        }
    }

    private func capsuleLabel(_ title: String, tone: ApxyDebugThemeTone) -> some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)
        let tint = tone.color(in: theme)

        return Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(tone == .muted ? 0.08 : 0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tone == .muted ? theme.border : tint.opacity(0.35))
            }
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
        statusColor: presentation.color(in: ApxyDebugTheme.palette(for: .light)),
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
        statusColor: presentation.color(in: ApxyDebugTheme.palette(for: .dark)),
        durationText: ApxyDebugValueFormatters.duration(record.duration),
        url: record.request.currentURL ?? record.request.url
    )
    .padding()
    .apxyPreviewComponent(.macOS)
}
#endif

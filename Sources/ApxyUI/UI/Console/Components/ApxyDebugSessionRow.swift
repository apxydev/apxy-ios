import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugSessionRow: View {
    let session: ApxyDebugSession
    var isActive: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Session \(ApxyDebugValueFormatters.sessionPrefix(session.id))")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                if isActive {
                    Text("LIVE")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.accentSoft, in: Capsule())
                        .foregroundStyle(theme.accent)
                }

                syncStateBadge(for: session.syncState, theme: theme)

                Spacer()

                Text(ApxyDebugValueFormatters.compactTimestamp(session.lastEventAt))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(theme.textMuted)
            }

            HStack(spacing: 12) {
                sessionMetric("\(session.requestCount)", label: "Requests", tone: .accent)
                sessionMetric("\(session.failureCount)", label: "Failures", tone: session.failureCount > 0 ? .error : .success)
                Spacer()
                Text("Started \(ApxyDebugValueFormatters.compactTimestamp(session.startedAt))")
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
            }
        }
        .padding(.vertical, ApxyDebugChrome.cardRowVerticalPadding)
        .padding(.horizontal, ApxyDebugChrome.cardRowHorizontalPadding)
        .background(ApxyDebugChrome.elevatedFill(in: theme))
        .overlay {
            RoundedRectangle(cornerRadius: ApxyDebugChrome.controlCornerRadius, style: .continuous)
                .stroke(isActive ? theme.accentBorder : theme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: ApxyDebugChrome.controlCornerRadius, style: .continuous))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func syncStateBadge(for syncState: ApxyLocalSessionSyncState, theme: ApxyDebugThemePalette) -> some View {
        switch syncState {
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
                .tint(theme.textMuted)
        case .synced:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(ApxyDebugThemeTone.success.color(in: theme))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(ApxyDebugThemeTone.error.color(in: theme))
        case .localOnly, .liveManaged:
            EmptyView()
        }
    }

    private func sessionMetric(
        _ value: String,
        label: String,
        tone: ApxyDebugThemeTone
    ) -> some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        return HStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(tone.color(in: theme))
    }
}

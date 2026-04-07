import SwiftUI
import ApxyCore

@available(iOS 16.0, macOS 13.0, *)
struct ApxyDebugRuntimeSettingsView: View {
    private enum Field: Hashable {
        case serverURL
        case flushInterval
        case capturedDomains
    }

    @ObservedObject var viewModel: ApxyDebugRuntimeSettingsViewModel

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    @State private var isPresentingClearConfirmation = false

    var body: some View {
        let theme = ApxyDebugTheme.palette(for: colorScheme)

        ScrollView {
            VStack(spacing: 16) {
                summaryCard(theme: theme)
                configurationCard(theme: theme)
                actionCard(theme: theme)
            }
            .frame(maxWidth: 760)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
#endif
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Runtime Settings")
        .apxyInlineTitle()
        .tint(theme.accent)
        .apxyNavigationChrome(theme: theme, colorScheme: colorScheme)
        .toolbar {
#if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
#endif
        }
    }

    private func summaryCard(theme: ApxyDebugThemePalette) -> some View {
        ApxyDebugSurfaceCard(style: .elevated, topAccent: theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tune the active debug session")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text(summaryDescription)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                ViewThatFits {
                    HStack(spacing: 8) {
                        sessionBadge(
                            title: viewModel.isRuntimeActive ? "Live Session" : "APXY Stopped",
                            tone: viewModel.isRuntimeActive ? .success : .warning,
                            theme: theme
                        )
                        sessionBadge(title: "Session Only", tone: .accent, theme: theme)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sessionBadge(
                            title: viewModel.isRuntimeActive ? "Live Session" : "APXY Stopped",
                            tone: viewModel.isRuntimeActive ? .success : .warning,
                            theme: theme
                        )
                        sessionBadge(title: "Session Only", tone: .accent, theme: theme)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(viewModel.activeSummary)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits {
                    HStack(spacing: 12) {
                        summaryMetric(
                            title: "Destination",
                            value: viewModel.activeDestinationSummary,
                            systemImage: "dot.radiowaves.left.and.right",
                            tone: .accent,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Flush",
                            value: viewModel.activeFlushIntervalSummary,
                            systemImage: "timer",
                            tone: .warning,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Domains",
                            value: viewModel.activeDomainSummary,
                            systemImage: "globe",
                            tone: .success,
                            theme: theme
                        )
                    }

                    VStack(spacing: 12) {
                        summaryMetric(
                            title: "Destination",
                            value: viewModel.activeDestinationSummary,
                            systemImage: "dot.radiowaves.left.and.right",
                            tone: .accent,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Flush",
                            value: viewModel.activeFlushIntervalSummary,
                            systemImage: "timer",
                            tone: .warning,
                            theme: theme
                        )
                        summaryMetric(
                            title: "Domains",
                            value: viewModel.activeDomainSummary,
                            systemImage: "globe",
                            tone: .success,
                            theme: theme
                        )
                    }
                }
            }
        }
    }

    private func configurationCard(theme: ApxyDebugThemePalette) -> some View {
        ApxyDebugSurfaceCard(style: .plain) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Configure session delivery")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)

                    Text("Adjust where traffic goes, how often APXY flushes, and which domains are captured.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ApxyDebugRuntimeSettingsFieldBlock(
                    title: "Server URL",
                    detail: "Leave empty to keep the session local-only, or point it at your APXY desktop instance.",
                    systemImage: "server.rack",
                    tint: .accent
                ) {
                    TextField("http://127.0.0.1:8083", text: $viewModel.serverURL)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .serverURL)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .flushInterval
                        }
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                }

                Divider()
                    .overlay(theme.border)

                ApxyDebugRuntimeSettingsFieldBlock(
                    title: "Flush interval",
                    detail: "Use a positive number of seconds. Smaller values stream updates faster but flush more often.",
                    systemImage: "timer",
                    tint: .warning
                ) {
                    TextField("2.0", text: $viewModel.flushIntervalText)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .flushInterval)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .capturedDomains
                        }
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }

                Divider()
                    .overlay(theme.border)

                ApxyDebugRuntimeSettingsFieldBlock(
                    title: "Captured domains",
                    detail: "Filter capture to specific hosts. Separate values with commas and use `*` for wildcard subdomains.",
                    systemImage: "globe",
                    tint: .success
                ) {
                    TextField("api.example.com, *.example.com", text: $viewModel.capturedDomainsText)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .capturedDomains)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                }
            }
        }
    }

    private func actionCard(theme: ApxyDebugThemePalette) -> some View {
        ApxyDebugSurfaceCard(
            style: .plain,
            topAccent: actionAccent(in: theme)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Apply to current session")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)

                    Text("Changes take effect immediately for the active runtime and reset when the app restarts.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    focusedField = nil
                    viewModel.applyChanges()
                } label: {
                    HStack(spacing: 12) {
                        if viewModel.isApplying {
                            ProgressView()
                                .tint(theme.canvas)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body.weight(.semibold))
                        }

                        Text(viewModel.applyButtonTitle)
                            .font(.headline)

                        Spacer(minLength: 12)

                        Text("Session only")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(theme.canvas.opacity(0.16), in: Capsule())
                    }
                    .foregroundStyle(theme.canvas)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isApplying || viewModel.isClearingData)
                .opacity(viewModel.isApplying || viewModel.isClearingData ? 0.85 : 1)

                Divider()
                    .overlay(theme.border)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Debug data")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Remove all captured requests and session history from this device without changing the active runtime configuration.")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        isPresentingClearConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            if viewModel.isClearingData {
                                ProgressView()
                                    .tint(theme.error)
                            } else {
                                Image(systemName: "trash")
                                    .font(.body.weight(.semibold))
                            }

                            Text(viewModel.clearButtonTitle)
                                .font(.headline)

                            Spacer(minLength: 12)
                        }
                        .foregroundStyle(theme.error)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(theme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.error.opacity(0.24))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isApplying || viewModel.isClearingData)
                    .opacity(viewModel.isApplying || viewModel.isClearingData ? 0.85 : 1)
                    .confirmationDialog(
                        "Clear all debug data?",
                        isPresented: $isPresentingClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All Data", role: .destructive) {
                            focusedField = nil
                            viewModel.clearAllData()
                        }

                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes all captured requests and sessions stored on this device.")
                    }
                }

                if let applyStatus = viewModel.applyStatus, let kind = viewModel.applyStatusKind {
                    ApxyDebugRuntimeSettingsStatusBanner(message: applyStatus, kind: kind)
                }

                Text("Invalid server URLs fall back to local-only mode without interrupting the rest of the debug session.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summaryDescription: String {
        if viewModel.isRuntimeActive {
            "Review the live configuration and make temporary adjustments without restarting the app."
        } else {
            "APXY is not running right now. You can prepare values here, but a live session is required before runtime changes take effect."
        }
    }

    private func actionAccent(in theme: ApxyDebugThemePalette) -> Color {
        switch viewModel.applyStatusKind {
        case .error:
            theme.error
        case .success:
            theme.success
        case nil:
            theme.accent
        }
    }

    private func sessionBadge(title: String, tone: ApxyDebugThemeTone, theme: ApxyDebugThemePalette) -> some View {
        let tint = tone.color(in: theme)

        return Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.28))
            }
    }

    private func summaryMetric(
        title: String,
        value: String,
        systemImage: String,
        tone: ApxyDebugThemeTone,
        theme: ApxyDebugThemePalette
    ) -> some View {
        let tint = tone.color(in: theme)

        return VStack(alignment: .leading, spacing: 8) {
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
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, *)
#Preview("Runtime Settings Light iOS") {
    Apxy.stop()
    Apxy.start(serverURL: "http://127.0.0.1:8083")

    let viewModel = ApxyDebugRuntimeSettingsViewModel()
    viewModel.serverURL = "http://127.0.0.1:9090"
    viewModel.flushIntervalText = "4.5"
    viewModel.capturedDomainsText = "api.example.com, *.example.com"
    viewModel.applyStatus = "Applied runtime settings (invalid URL fallback: local-only if needed)."
    viewModel.applyStatusKind = .success

    return NavigationStack {
        ApxyDebugRuntimeSettingsView(viewModel: viewModel)
    }
    .apxyPreviewScreen(.iOS)
    .preferredColorScheme(.light)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Runtime Settings Dark macOS") {
    Apxy.stop()

    let viewModel = ApxyDebugRuntimeSettingsViewModel()
    viewModel.serverURL = ""
    viewModel.flushIntervalText = "zero"
    viewModel.capturedDomainsText = "staging.apxy.dev"
    viewModel.applyStatus = "Enter a valid flush interval (> 0)."
    viewModel.applyStatusKind = .error

    return NavigationStack {
        ApxyDebugRuntimeSettingsView(viewModel: viewModel)
    }
    .apxyPreviewScreen(.macOS)
    .preferredColorScheme(.dark)
}
#endif

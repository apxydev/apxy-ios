import Foundation
import ApxyCore

@MainActor
final class ApxyDebugRuntimeSettingsViewModel: ObservableObject {
    private let debugStore: ApxyDebugStore?

    enum StatusKind: Equatable {
        case success
        case error
    }

    @Published var serverURL: String = ""
    @Published var flushIntervalText: String = "2.0"
    @Published var capturedDomainsText: String = ""
    @Published var applyStatus: String?
    @Published var applyStatusKind: StatusKind?
    @Published var isApplying = false
    @Published var isClearingData = false

    init(debugStore: ApxyDebugStore? = Apxy.activeDebugStore) {
        self.debugStore = debugStore
        reloadFromActiveRuntime()
    }

    var isRuntimeActive: Bool {
        Apxy.activeRuntimeConfiguration != nil
    }

    var activeSummary: String {
        guard let config = Apxy.activeRuntimeConfiguration else {
            return "APXY is not running"
        }

        let destination = config.serverURL.flatMap { !$0.isEmpty ? $0 : nil } ?? "local-only"
        let flush = String(format: "%.1f", config.flushInterval)
        let domains = {
            guard let capturedDomains = config.capturedDomains, !capturedDomains.isEmpty else {
                return "all"
            }
            return capturedDomains.joined(separator: ", ")
        }()

        return "Endpoint: \(destination)" +
            " • Flush interval: \(flush)s" +
            " • Captured domains: \(domains)"
    }

    var activeDestinationSummary: String {
        guard let config = Apxy.activeRuntimeConfiguration else {
            return "Offline"
        }

        return config.serverURL.flatMap { !$0.isEmpty ? $0 : nil } ?? "Local-only"
    }

    var activeFlushIntervalSummary: String {
        guard let config = Apxy.activeRuntimeConfiguration else {
            return "--"
        }

        return String(format: "%.1fs", config.flushInterval)
    }

    var activeDomainSummary: String {
        guard let config = Apxy.activeRuntimeConfiguration else {
            return "--"
        }

        guard let capturedDomains = config.capturedDomains, !capturedDomains.isEmpty else {
            return "All domains"
        }

        if capturedDomains.count == 1, let first = capturedDomains.first {
            return first
        }

        return "\(capturedDomains.count) domains"
    }

    var applyButtonTitle: String {
        isApplying ? "Applying..." : "Apply Changes"
    }

    var clearButtonTitle: String {
        isClearingData ? "Clearing..." : "Clear All Data"
    }

    func reloadFromActiveRuntime() {
        guard let config = Apxy.activeRuntimeConfiguration else {
            serverURL = ""
            flushIntervalText = "2.0"
            capturedDomainsText = ""
            return
        }

        serverURL = config.serverURL ?? ""
        flushIntervalText = String(format: "%.1f", config.flushInterval)
        capturedDomainsText = config.capturedDomains?.joined(separator: ", ") ?? ""
    }

    func applyChanges() {
        guard !isApplying, !isClearingData else { return }

        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedServerURL = trimmedServerURL.isEmpty ? nil : trimmedServerURL

        guard let flushInterval = Double(flushIntervalText.trimmingCharacters(in: .whitespacesAndNewlines)),
              flushInterval > 0 else {
            applyStatus = "Enter a valid flush interval (> 0)."
            applyStatusKind = .error
            return
        }

        let parsedDomains = parseDomains(capturedDomainsText)

        isApplying = true
        defer { isApplying = false }

        let request = ApxyRuntimeConfiguration(
            serverURL: normalizedServerURL,
            flushInterval: flushInterval,
            capturedDomains: parsedDomains
        )
        Apxy.reconfigure(request)
        reloadFromActiveRuntime()
        applyStatus = "Applied runtime settings (invalid URL fallback: local-only if needed)."
        applyStatusKind = .success
    }

    func clearAllData() {
        guard !isApplying, !isClearingData else { return }
        guard let debugStore else {
            applyStatus = "Debug data is unavailable right now."
            applyStatusKind = .error
            return
        }

        isClearingData = true

        Task {
            await debugStore.clear()
            isClearingData = false
            applyStatus = "Cleared all captured sessions and requests."
            applyStatusKind = .success
        }
    }

    private func parseDomains(_ value: String) -> [String]? {
        let domains = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return domains.isEmpty ? nil : Array(domains)
    }
}

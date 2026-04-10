import Foundation
import ApxyCore

@MainActor
final class ApxyDebugRuntimeSettingsViewModel: ObservableObject {
    private let debugStore: ApxyDebugStore?
    private let defaultFlushInterval = 2.0

    enum StatusKind: Equatable {
        case success
        case error
    }

    @Published var serverURL: String = ""
    @Published var keyID: String = ""
    @Published var clientSecret: String = ""
    @Published var capturedDomainsText: String = ""
    @Published var applyStatus: String?
    @Published var applyStatusKind: StatusKind?
    @Published var isApplying = false
    @Published var isClearingData = false

    private static let rejectedRemoteSettingsMessage =
        "Couldn't apply remote runtime settings. Check the server URL and signed ingest credentials."

    init(debugStore: ApxyDebugStore? = Apxy.activeDebugStore) {
        self.debugStore = debugStore
        reloadFromActiveRuntime()
    }

    var isRuntimeActive: Bool {
        Apxy.activeRuntimeConfiguration != nil
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
            keyID = ""
            clientSecret = ""
            capturedDomainsText = ""
            return
        }

        serverURL = config.remote?.serverURL ?? ""
        keyID = config.remote?.ingestCredentials.keyID ?? ""
        clientSecret = config.remote?.ingestCredentials.clientSecret ?? ""
        capturedDomainsText = config.capturedDomains?.joined(separator: ", ") ?? ""
    }

    func applyChanges() {
        guard !isApplying, !isClearingData else { return }

        let trimmedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedServerURL = trimmedServerURL.isEmpty ? nil : trimmedServerURL
        let trimmedKeyID = keyID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let flushInterval = Apxy.activeRuntimeConfiguration?.flushInterval ?? defaultFlushInterval

        if normalizedServerURL != nil && (trimmedKeyID.isEmpty || trimmedClientSecret.isEmpty) {
            applyStatus = "Enter both Key ID and Client Secret for remote ingest."
            applyStatusKind = .error
            return
        }
        let parsedDomains = parseDomains(capturedDomainsText)
        let remote: ApxyRemoteConfiguration? = {
            guard let normalizedServerURL else { return nil }
            return ApxyRemoteConfiguration(
                serverURL: normalizedServerURL,
                ingestCredentials: ApxyIngestCredentials(keyID: trimmedKeyID, clientSecret: trimmedClientSecret)
            )
        }()

        isApplying = true
        defer { isApplying = false }

        let request = ApxyRuntimeConfiguration(
            remote: remote,
            flushInterval: flushInterval,
            capturedDomains: parsedDomains
        )
        if Apxy.reconfigure(request) {
            reloadFromActiveRuntime()
            applyStatus = "Applied runtime settings."
            applyStatusKind = .success
            return
        }

        applyStatus = Self.rejectedRemoteSettingsMessage
        applyStatusKind = .error
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

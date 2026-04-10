import Foundation

/// Errors surfaced by manual sharing of persisted local sessions.
public enum ApxyLocalSessionShareError: LocalizedError, Sendable {
    case sdkNotRunning
    case debugConsoleDisabled
    case missingServerURL
    case missingIngestCredentials

    public var errorDescription: String? {
        switch self {
        case .sdkNotRunning:
            return "APXY must be running before sharing a local session"
        case .debugConsoleDisabled:
            return "Local debug persistence is disabled"
        case .missingServerURL:
            return "Set a valid serverURL before sharing a local session"
        case .missingIngestCredentials:
            return "Set valid signed ingest credentials before sharing a local session"
        }
    }
}

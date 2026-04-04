import Foundation

enum SDKError: LocalizedError {
    case invalidURL
    case serverError(Int)
    case transportUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .serverError(let code):
            return "Server returned HTTP \(code)"
        case .transportUnavailable:
            return "Record transport is unavailable"
        }
    }
}

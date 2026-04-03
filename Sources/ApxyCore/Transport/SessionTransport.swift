import Foundation

protocol SessionTransporting: Actor, Sendable {
    func registerClient(_ client: SDKClient) async throws
    func createSession(id: String, clientID: String, context: ClientContext) async throws
    func updateSessionContext(id: String, context: ClientContext) async throws
}

/// Handles low-frequency session and client registration HTTP calls.
/// Uses its own `URLSession` (not intercepted) to avoid recursion.
actor SessionTransport: SessionTransporting {
    private let serverURL: URL
    private let session: URLSession

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()

    init(serverURL: URL) {
        self.serverURL = serverURL

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["X-Apxy-SDK-Internal": "1"]
        self.session = URLSession(configuration: config)
    }

    func registerClient(_ client: SDKClient) async throws {
        try await post(path: "/api/v1/sdk/clients", body: encoder.encode(client))
    }

    func createSession(
        id: String,
        clientID: String,
        context: ClientContext
    ) async throws {
        struct Payload: Encodable {
            let id: String
            let sdk_client_id: String
            let user_context: ClientContext
        }

        let payload = Payload(id: id, sdk_client_id: clientID, user_context: context)
        try await post(path: "/api/v1/sdk/sessions", body: encoder.encode(payload))
    }

    func updateSessionContext(
        id: String,
        context: ClientContext
    ) async throws {
        try await patch(path: "/api/v1/sdk/sessions/\(id)", body: encoder.encode(context))
    }

    private func post(path: String, body: Data) async throws {
        try await request(method: "POST", path: path, body: body)
    }

    private func patch(path: String, body: Data) async throws {
        try await request(method: "PATCH", path: path, body: body)
    }

    private func request(method: String, path: String, body: Data) async throws {
        guard let url = URL(string: path, relativeTo: serverURL) else {
            throw SDKError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw SDKError.serverError(http.statusCode)
        }
    }
}

enum SDKError: LocalizedError {
    case encodingFailed
    case invalidURL
    case serverError(Int)
    case transportUnavailable

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode payload"
        case .invalidURL:
            return "Invalid server URL"
        case .serverError(let code):
            return "Server returned HTTP \(code)"
        case .transportUnavailable:
            return "Record transport is unavailable"
        }
    }
}

import Foundation

/// Handles low-frequency session and client registration HTTP calls.
/// Uses its own `URLSession` (not intercepted) to avoid recursion.
final class SessionTransport: @unchecked Sendable {
    private let serverURL: URL
    private let session: URLSession

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(SessionTransport.iso8601.string(from: date))
        }
        return e
    }()

    init(serverURL: URL) {
        self.serverURL = serverURL
        // Use a dedicated session with a custom header to identify SDK traffic
        // so the interceptor can exclude it from capture.
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["X-Apxy-SDK-Internal": "1"]
        self.session = URLSession(configuration: config)
    }

    // MARK: Client registration

    func registerClient(_ client: SDKClient, completion: @escaping (Error?) -> Void) {
        guard let body = try? encoder.encode(client) else {
            completion(SDKError.encodingFailed)
            return
        }
        post(path: "/api/v1/sdk/clients", body: body, completion: completion)
    }

    // MARK: Session management

    func createSession(
        id: String,
        clientID: String,
        context: ClientContext,
        completion: @escaping (Error?) -> Void
    ) {
        struct Payload: Encodable {
            let id: String
            let sdk_client_id: String
            let user_context: ClientContext
        }
        guard let body = try? encoder.encode(Payload(id: id, sdk_client_id: clientID, user_context: context)) else {
            completion(SDKError.encodingFailed)
            return
        }
        post(path: "/api/v1/sdk/sessions", body: body, completion: completion)
    }

    func updateSessionContext(
        id: String,
        context: ClientContext,
        completion: @escaping (Error?) -> Void
    ) {
        guard let body = try? encoder.encode(context) else {
            completion(SDKError.encodingFailed)
            return
        }
        patch(path: "/api/v1/sdk/sessions/\(id)", body: body, completion: completion)
    }

    // MARK: Helpers

    private func post(path: String, body: Data, completion: @escaping (Error?) -> Void) {
        request(method: "POST", path: path, body: body, completion: completion)
    }

    private func patch(path: String, body: Data, completion: @escaping (Error?) -> Void) {
        request(method: "PATCH", path: path, body: body, completion: completion)
    }

    private func request(method: String, path: String, body: Data, completion: @escaping (Error?) -> Void) {
        guard let url = URL(string: path, relativeTo: serverURL) else {
            completion(SDKError.invalidURL)
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        session.dataTask(with: req) { _, response, error in
            if let error {
                completion(error)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                completion(SDKError.serverError(http.statusCode))
                return
            }
            completion(nil)
        }.resume()
    }
}

enum SDKError: LocalizedError {
    case encodingFailed
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:   return "Failed to encode payload"
        case .invalidURL:       return "Invalid server URL"
        case .serverError(let code): return "Server returned HTTP \(code)"
        }
    }
}

import Foundation

/// Batch POST transport used by the buffered delivery mode.
actor HTTPTransport: RecordTransport {
    private let serverURL: URL
    private let session: URLSession
    private let connectionStateTracker: ConnectionStateTracker

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(serverURL: URL, connectionStateTracker: ConnectionStateTracker) {
        self.serverURL = serverURL
        self.connectionStateTracker = connectionStateTracker

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["X-Apxy-SDK-Internal": "1"]
        self.session = URLSession(configuration: config)
    }

    func start() async {}

    func stop() async {}

    func send(records: [NetworkRecord]) async throws {
        guard !records.isEmpty else { return }

        let body = try encoder.encode(records)
        guard let url = URL(string: "/api/v1/sdk/traffic", relativeTo: serverURL) else {
            throw SDKError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let reason = "HTTP \(http.statusCode)"
                SDKLogger.warn("cannot reach server (HTTP flush): \(reason)")
                await connectionStateTracker.reportServerEndpointFailure(reason: reason)
                throw SDKError.serverError(http.statusCode)
            }

            await connectionStateTracker.reportServerEndpointSuccess()
            SDKLogger.debug("HTTPTransport flush succeeded recordCount=\(records.count)")
        } catch {
            SDKLogger.warn("cannot reach server (HTTP flush): \(error.localizedDescription)")
            await connectionStateTracker.reportServerEndpointFailure(reason: error.localizedDescription)
            throw error
        }
    }
}

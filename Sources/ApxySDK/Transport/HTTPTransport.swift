import Foundation

/// Batch-POST transport: collects records, flushes on a timer.
/// Uses its own URLSession (marked internal) to avoid interception.
final class HTTPTransport: RecordTransport, @unchecked Sendable {
    private let serverURL: URL
    private let buffer: RecordBuffer
    private let flushInterval: TimeInterval
    private let session: URLSession
    private let connectionStateTracker: ConnectionStateTracker
    private var timer: Timer?

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(
        serverURL: URL,
        buffer: RecordBuffer,
        flushInterval: TimeInterval,
        connectionStateTracker: ConnectionStateTracker
    ) {
        self.serverURL = serverURL
        self.buffer = buffer
        self.flushInterval = flushInterval
        self.connectionStateTracker = connectionStateTracker

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["X-Apxy-SDK-Internal": "1"]
        self.session = URLSession(configuration: config)
    }

    func start() {
        SDKLogger.debug("HTTPTransport timer started interval=\(flushInterval)s")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(
                withTimeInterval: self.flushInterval,
                repeats: true
            ) { [weak self] _ in self?.flush() }
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in self?.timer?.invalidate() }
        flush()
    }

    func send(records: [NetworkRecord], completion: @escaping (Error?) -> Void) {
        guard !records.isEmpty else { completion(nil); return }
        guard let body = try? encoder.encode(records) else {
            completion(SDKError.encodingFailed)
            return
        }
        guard let url = URL(string: "/api/v1/sdk/traffic", relativeTo: serverURL) else {
            completion(SDKError.invalidURL)
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        session.dataTask(with: req) { [weak self] _, response, error in
            guard let self else { return }
            if let error {
                let reason = error.localizedDescription
                SDKLogger.warn("cannot reach server (HTTP flush): \(reason)")
                self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
                completion(error)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let reason = "HTTP \(http.statusCode)"
                SDKLogger.warn("cannot reach server (HTTP flush): \(reason)")
                self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
                completion(SDKError.serverError(http.statusCode))
                return
            }
            completion(nil)
            self.connectionStateTracker.reportServerEndpointSuccess()
            SDKLogger.debug("HTTPTransport flush succeeded recordCount=\(records.count)")
        }.resume()
    }

    private func flush() {
        let records = buffer.drain()
        guard !records.isEmpty else { return }
        send(records: records) { _ in }
    }
}

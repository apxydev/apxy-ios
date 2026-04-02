import Foundation

/// Real-time WebSocket transport: streams records one-by-one to APXY Core.
/// Automatically reconnects on disconnect. Falls back to HTTP flush on failure.
@available(iOS 13.0, macOS 10.15, *)
final class WebSocketTransport: RecordTransport, @unchecked Sendable {
    private let serverURL: URL
    private let buffer: RecordBuffer
    private let session: URLSession
    private let connectionStateTracker: ConnectionStateTracker
    private var wsTask: URLSessionWebSocketTask?
    private var reconnectDelay: TimeInterval = 1.0
    private var stopped = false
    private var lastDisconnectLogAt: TimeInterval = 0
    private let disconnectLogThrottleSeconds: TimeInterval = 2.0

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(serverURL: URL, buffer: RecordBuffer, connectionStateTracker: ConnectionStateTracker) {
        self.serverURL = serverURL
        self.buffer = buffer
        self.connectionStateTracker = connectionStateTracker

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["X-Apxy-SDK-Internal": "1"]
        self.session = URLSession(configuration: config)
    }

    func start() {
        stopped = false
        connect()
    }

    func stop() {
        stopped = true
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
    }

    func send(records: [NetworkRecord], completion: @escaping (Error?) -> Void) {
        guard let task = wsTask, task.state == .running else {
            for r in records { buffer.append(r) }
            SDKLogger.debug("WebSocket not running; re-buffered \(records.count) record(s)")
            completion(nil)
            return
        }
        guard let data = try? encoder.encode(records) else {
            completion(SDKError.encodingFailed)
            return
        }
        task.send(.data(data)) { [weak self] error in
            guard let self else { return }
            if let error {
                let reason = error.localizedDescription
                SDKLogger.warn("WebSocketTransport send failed: \(reason)")
                self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
                completion(error)
            } else {
                self.connectionStateTracker.reportServerEndpointSuccess()
                completion(nil)
            }
        }
    }

    // MARK: Connection

    private func connect() {
        guard let url = URL(string: "/api/v1/sdk/traffic/ws", relativeTo: serverURL) else { return }
        let host = serverURL.host ?? "?"
        SDKLogger.debug("WebSocketTransport connecting host=\(host) path=\(url.path)")
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "X-Apxy-SDK-Internal")
        wsTask = session.webSocketTask(with: request)
        wsTask?.resume()
        reconnectDelay = 1.0
        flushBuffered()
        listenForMessages()
    }

    private func listenForMessages() {
        wsTask?.receive { [weak self] result in
            guard let self, !self.stopped else { return }
            switch result {
            case .failure(let error):
                let reason = error.localizedDescription
                let now = ProcessInfo.processInfo.systemUptime
                let delta = now - self.lastDisconnectLogAt
                if self.lastDisconnectLogAt == 0 || delta >= self.disconnectLogThrottleSeconds {
                    SDKLogger.warn("WebSocketTransport disconnected: \(error)")
                    self.lastDisconnectLogAt = now
                } else {
                    SDKLogger.debug("WebSocketTransport disconnected (throttled): \(error)")
                }
                self.connectionStateTracker.reportTransportDisconnected(reason: reason)
                self.connectionStateTracker.reportServerEndpointFailure(reason: "WebSocket: \(reason)")
                self.scheduleReconnect()
            case .success:
                self.listenForMessages()
            }
        }
    }

    private func scheduleReconnect() {
        guard !stopped else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self, !self.stopped else { return }
            self.reconnectDelay = min(self.reconnectDelay * 2, 30)
            self.connect()
        }
    }

    private func flushBuffered() {
        let records = buffer.drain()
        guard !records.isEmpty else { return }
        send(records: records) { [weak self] error in
            guard let self else { return }
            if let error {
                let reason = error.localizedDescription
                SDKLogger.warn("WebSocketTransport flushBuffered: \(error)")
                self.connectionStateTracker.reportServerEndpointFailure(reason: reason)
            } else {
                self.connectionStateTracker.reportServerEndpointSuccess()
            }
        }
    }
}

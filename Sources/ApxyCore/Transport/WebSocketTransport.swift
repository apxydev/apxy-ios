import Foundation

/// Real-time WebSocket transport: streams records one-by-one to APXY Core.
/// Automatically reconnects on disconnect.
@available(iOS 13.0, macOS 10.15, *)
actor WebSocketTransport: RecordTransport {
    private let serverURL: URL
    private let session: URLSession
    private let connectionStateTracker: ConnectionStateTracker
    private var wsTask: URLSessionWebSocketTask?
    private var reconnectDelay: TimeInterval = 1.0
    private var isRunning = false
    private var lastDisconnectLogAt: TimeInterval = 0
    private let disconnectLogThrottleSeconds: TimeInterval = 2.0
    private var reconnectTask: Task<Void, Never>?

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

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        await connect()
    }

    func stop() async {
        isRunning = false
        reconnectTask?.cancel()
        reconnectTask = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
    }

    func send(records: [NetworkRecord]) async throws {
        guard let task = wsTask, task.state == .running else {
            throw SDKError.transportUnavailable
        }

        let data = try encoder.encode(records)

        do {
            try await sendMessage(.data(data), on: task)
            await connectionStateTracker.reportServerEndpointSuccess()
        } catch {
            let reason = error.localizedDescription
            SDKLogger.warn("WebSocketTransport send failed: \(reason)")
            await connectionStateTracker.reportServerEndpointFailure(reason: reason)
            await scheduleReconnect()
            throw error
        }
    }

    private func connect() async {
        guard let url = Self.webSocketURL(for: serverURL) else {
            SDKLogger.warn("WebSocketTransport: invalid serverURL '\(serverURL.absoluteString)'")
            await connectionStateTracker.reportServerEndpointFailure(reason: "Invalid WebSocket URL")
            return
        }

        let host = serverURL.host ?? "?"
        SDKLogger.debug("WebSocketTransport connecting host=\(host) path=\(url.path)")

        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "X-Apxy-SDK-Internal")

        let task = session.webSocketTask(with: request)
        wsTask = task
        task.resume()
        reconnectDelay = 1.0
        listenForMessages(on: task)
    }

    private func listenForMessages(on task: URLSessionWebSocketTask) {
        Task {
            do {
                while shouldContinueListening(task) {
                    _ = try await receiveMessage(on: task)
                }
            } catch {
                guard shouldHandleDisconnect(for: task) else { return }

                let reason = error.localizedDescription
                let now = ProcessInfo.processInfo.systemUptime
                let previousDisconnect = lastDisconnectTimestamp()
                let delta = now - previousDisconnect

                if previousDisconnect == 0 || delta >= disconnectLogThrottleSeconds {
                    SDKLogger.warn("WebSocketTransport disconnected: \(error)")
                    setLastDisconnectTimestamp(now)
                } else {
                    SDKLogger.debug("WebSocketTransport disconnected (throttled): \(error)")
                }

                await connectionStateTracker.reportTransportDisconnected(reason: reason)
                await connectionStateTracker.reportServerEndpointFailure(reason: "WebSocket: \(reason)")
                await scheduleReconnect()
            }
        }
    }

    private func shouldContinueListening(_ task: URLSessionWebSocketTask) -> Bool {
        isRunning && task == wsTask
    }

    private func shouldHandleDisconnect(for task: URLSessionWebSocketTask) -> Bool {
        isRunning && task == wsTask
    }

    private func scheduleReconnect() async {
        guard isRunning, reconnectTask == nil else { return }

        let delay = reconnectDelay
        reconnectTask = Task {
            do {
                try await Task.sleep(nanoseconds: sleepNanoseconds(for: delay))
                await self.finishReconnect(after: delay)
            } catch {}
        }
    }

    private func finishReconnect(after delay: TimeInterval) async {
        reconnectTask = nil
        guard isRunning else { return }

        reconnectDelay = min(delay * 2, 30)
        await connect()
    }

    private func lastDisconnectTimestamp() -> TimeInterval {
        lastDisconnectLogAt
    }

    private func setLastDisconnectTimestamp(_ value: TimeInterval) {
        lastDisconnectLogAt = value
    }

    private func sendMessage(
        _ message: URLSessionWebSocketTask.Message,
        on task: URLSessionWebSocketTask
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(message) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func receiveMessage(on task: URLSessionWebSocketTask) async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { continuation in
            task.receive { result in
                continuation.resume(with: result)
            }
        }
    }

    static func webSocketURL(for serverURL: URL) -> URL? {
        guard var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        switch components.scheme?.lowercased() {
        case "http":
            components.scheme = "ws"
        case "https":
            components.scheme = "wss"
        case "ws", "wss":
            break
        default:
            return nil
        }

        components.path = ""
        components.query = nil
        components.fragment = nil

        guard let baseURL = components.url else { return nil }
        return URL(string: "/api/v1/sdk/traffic/ws", relativeTo: baseURL)
    }
}

private func sleepNanoseconds(for duration: TimeInterval) -> UInt64 {
    UInt64(max(0, duration) * 1_000_000_000)
}

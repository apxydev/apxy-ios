import Foundation

/// Tracks APXY server endpoint reachability for session + record transports and
/// emits `ApxyConnectionEvent` without duplicating `serverUnavailable` on every retry.
final class ConnectionStateTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var serverEndpointReachable = true
    private let sink: @Sendable (ApxyConnectionEvent) -> Void

    init(sink: @escaping @Sendable (ApxyConnectionEvent) -> Void) {
        self.sink = sink
    }

    func reportServerEndpointFailure(reason: String) {
        lock.lock()
        let wasReachable = serverEndpointReachable
        serverEndpointReachable = false
        lock.unlock()
        if wasReachable {
            sink(.serverUnavailable(reason: reason))
        }
    }

    func reportServerEndpointSuccess() {
        lock.lock()
        let wasUnreachable = !serverEndpointReachable
        serverEndpointReachable = true
        lock.unlock()
        if wasUnreachable {
            sink(.serverRecovered)
        }
    }

    func reportTransportDisconnected(reason: String?) {
        sink(.transportDisconnected(reason: reason))
    }
}

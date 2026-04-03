import Foundation

/// Tracks APXY server endpoint reachability for session + record transports and
/// emits `ApxyConnectionEvent` without duplicating `serverUnavailable` on every retry.
actor ConnectionStateTracker {
    private var serverEndpointReachable = true
    private let sink: @Sendable (ApxyConnectionEvent) -> Void

    init(sink: @escaping @Sendable (ApxyConnectionEvent) -> Void) {
        self.sink = sink
    }

    func reportServerEndpointFailure(reason: String) {
        let wasReachable = serverEndpointReachable
        serverEndpointReachable = false
        if wasReachable {
            sink(.serverUnavailable(reason: reason))
        }
    }

    func reportServerEndpointSuccess() {
        let wasUnreachable = !serverEndpointReachable
        serverEndpointReachable = true
        if wasUnreachable {
            sink(.serverRecovered)
        }
    }

    func reportTransportDisconnected(reason: String?) {
        sink(.transportDisconnected(reason: reason))
    }
}

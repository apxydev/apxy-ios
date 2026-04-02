import Foundation
import Network

struct ConnectionSnapshot: Sendable, Equatable {
    let isConnected: Bool
    let networkType: String

    static let unknown = ConnectionSnapshot(isConnected: false, networkType: "unknown")
}

/// Monitors network reachability using `NWPathMonitor` and reports immutable
/// snapshots back to the SDK runtime.
final class ConnectionMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.apxy.sdk.connection-monitor")
    private let onUpdate: @Sendable (ConnectionSnapshot) -> Void

    init(onUpdate: @escaping @Sendable (ConnectionSnapshot) -> Void) {
        self.onUpdate = onUpdate
        monitor.pathUpdateHandler = { [onUpdate] path in
            let type: String
            if path.usesInterfaceType(.wifi) {
                type = "wifi"
            } else if path.usesInterfaceType(.cellular) {
                type = "cellular"
            } else if path.usesInterfaceType(.wiredEthernet) {
                type = "ethernet"
            } else {
                type = "other"
            }

            onUpdate(
                ConnectionSnapshot(
                    isConnected: path.status == .satisfied,
                    networkType: type
                )
            )
        }
    }

    func start() {
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

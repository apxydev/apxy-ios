import Foundation
import Network

/// Monitors network reachability using `NWPathMonitor` and reports connection
/// status changes. Also detects WiFi vs Cellular.
final class ConnectionMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.apxy.sdk.connection-monitor")

    private(set) var isConnected: Bool = false
    private(set) var networkType: String = "unknown"

    var onStatusChange: ((Bool, String) -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
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
            self.isConnected = connected
            self.networkType = type
            self.onStatusChange?(connected, type)
        }
    }

    func start() {
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

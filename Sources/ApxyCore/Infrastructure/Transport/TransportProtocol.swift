import Foundation

/// Abstract transport for sending buffered `NetworkRecord`s to APXY Core.
protocol RecordTransport: AnyObject, Sendable {
    func send(records: [NetworkRecord]) async throws
    func start() async
    func stop() async
}

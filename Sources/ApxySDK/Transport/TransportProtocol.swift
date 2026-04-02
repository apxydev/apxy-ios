import Foundation

/// Abstract transport for sending buffered `NetworkRecord`s to APXY Core.
protocol RecordTransport: AnyObject {
    func send(records: [NetworkRecord], completion: @escaping (Error?) -> Void)
    func start()
    func stop()
}

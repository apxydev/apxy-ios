import Foundation

/// No-op transports used when the SDK is running in local-only mode without a remote APXY server.
actor LocalOnlySessionTransport: SessionTransporting {
    func registerClient(_ client: SDKClient) async throws {}

    func createSession(
        id: String,
        name: String?,
        createdAt: Date?,
        clientID: String,
        context: ClientContext
    ) async throws {}

    func updateSessionContext(id: String, context: ClientContext) async throws {}
}

actor LocalOnlyRecordTransport: RecordTransport {
    func start() async {}

    func stop() async {}

    func send(records: [NetworkRecord]) async throws {}
}

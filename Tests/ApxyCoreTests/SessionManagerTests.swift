import Foundation
import Testing
@testable import ApxyCore

struct SessionManagerTests {
    @Test func startRegistersClientAndCreatesInitialSession() async {
        let sessionTransport = MockSessionTransport()
        let recordTransport = MockRecordTransport()
        let tracker = ConnectionStateTracker { _ in }
        let manager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            serverURL: nil,
            connectionStateTracker: tracker,
            bufferCapacity: 16,
            recordDeliveryMode: .buffered,
            flushInterval: 30,
            sessionIdleTimeout: 300
        )

        await manager.start()

        #expect(await sessionTransport.registerCount == 1)
        #expect(await sessionTransport.createCalls.count == 1)
        #expect(await recordTransport.startCount == 1)
    }

    @Test func contextUpdatesTargetTheActiveSession() async throws {
        let sessionTransport = MockSessionTransport()
        let recordTransport = MockRecordTransport()
        let tracker = ConnectionStateTracker { _ in }
        let manager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            serverURL: nil,
            connectionStateTracker: tracker,
            bufferCapacity: 16,
            recordDeliveryMode: .buffered,
            flushInterval: 30,
            sessionIdleTimeout: 300
        )

        await manager.start()
        await manager.setUser(ApxyUser(id: "user-1", email: "dev@example.com"))

        let update = try #require(await sessionTransport.updateCalls.first)
        #expect(update.context.userID == "user-1")
        #expect(update.context.userEmail == "dev@example.com")
    }

    @Test func immediateModeRebuffersFailedSends() async {
        let sessionTransport = MockSessionTransport()
        let recordTransport = MockRecordTransport(sendError: MockError.sendFailed)
        let tracker = ConnectionStateTracker { _ in }
        let manager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            serverURL: nil,
            connectionStateTracker: tracker,
            bufferCapacity: 16,
            recordDeliveryMode: .immediate,
            flushInterval: 30,
            sessionIdleTimeout: 300
        )

        await manager.start()
        await manager.capture(makePayload(id: "r1"))

        #expect(await recordTransport.sentBatches.count == 1)
        #expect(await manager.bufferedRecordCount() == 1)
    }

    @Test func foregroundResumeWithinTimeoutDoesNotCreateANewSession() async {
        let sessionTransport = MockSessionTransport()
        let recordTransport = MockRecordTransport()
        let tracker = ConnectionStateTracker { _ in }
        let manager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            serverURL: nil,
            connectionStateTracker: tracker,
            bufferCapacity: 16,
            recordDeliveryMode: .buffered,
            flushInterval: 30,
            sessionIdleTimeout: 300
        )

        await manager.start()
        await manager.appDidEnterBackground()
        await manager.appDidBecomeActive()

        #expect(await sessionTransport.createCalls.count == 1)
    }

    @Test func reconfigureFlushesBufferedRecordsBeforeSwitchingTransport() async throws {
        let sessionTransport = MockSessionTransport()
        let recordTransport = MockRecordTransport()
        let tracker = ConnectionStateTracker { _ in }
        let manager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            serverURL: nil,
            connectionStateTracker: tracker,
            bufferCapacity: 16,
            recordDeliveryMode: .buffered,
            flushInterval: 30,
            sessionIdleTimeout: 300
        )

        await manager.start()
        await manager.capture(makePayload(id: "r1"))

        let newSessionTransport = MockSessionTransport()
        let newRecordTransport = MockRecordTransport()
        await manager.reconfigure(
            transport: newSessionTransport,
            recordTransport: newRecordTransport,
            serverURL: nil,
            recordDeliveryMode: .buffered,
            flushInterval: 5
        )

        let flushedBatch = try #require(await recordTransport.sentBatches.first)
        #expect(flushedBatch.count == 1)
        #expect(flushedBatch.first?.url == "https://example.com/r1")
        #expect(await newRecordTransport.sentBatches.isEmpty)
        #expect(await recordTransport.stopCount == 1)
        #expect(await newRecordTransport.startCount == 1)
    }

    @Test func reconfigureFailureKeepsSessionRetryStateIntact() async {
        let sessionTransport = MockSessionTransport()
        let recordTransport = MockRecordTransport()
        let tracker = ConnectionStateTracker { _ in }
        let manager = SessionManager(
            transport: sessionTransport,
            recordTransport: recordTransport,
            serverURL: nil,
            connectionStateTracker: tracker,
            bufferCapacity: 16,
            recordDeliveryMode: .buffered,
            flushInterval: 30,
            sessionIdleTimeout: 0
        )

        await manager.start()

        let failingTransport = MockSessionTransport(registerError: MockError.registerFailed)
        await manager.reconfigure(
            transport: failingTransport,
            recordTransport: MockRecordTransport(),
            serverURL: nil,
            recordDeliveryMode: .buffered,
            flushInterval: 5
        )

        await manager.appDidEnterBackground()
        await manager.appDidBecomeActive()

        #expect(await failingTransport.registerCount == 1)
        #expect(await failingTransport.createCalls.count == 1)
    }

    private func makePayload(id: String) -> CapturePayload {
        CapturePayload(
            requestMethod: "GET",
            url: "https://example.com/\(id)",
            host: "example.com",
            path: "/\(id)",
            requestHeaders: nil,
            requestBody: nil,
            requestBodySource: .unavailable,
            requestBodySize: nil,
            requestContentType: nil,
            finalURL: nil,
            finalHost: nil,
            finalPath: nil,
            finalRequestHeaders: nil,
            statusCode: 200,
            responseHeaders: nil,
            responseBody: nil,
            responseBodySize: nil,
            responseContentType: nil,
            redirectCount: 0,
            duration: 1_000_000,
            tls: true,
            hadError: false,
            expectedResponseBodySize: nil,
            transferSize: .empty
        )
    }
}

private actor MockSessionTransport: SessionTransporting {
    struct CreateCall: Sendable {
        let id: String
        let clientID: String
        let context: ClientContext
    }

    struct UpdateCall: Sendable {
        let id: String
        let context: ClientContext
    }

    private let registerError: Error?
    private let createError: Error?
    private let updateError: Error?

    private(set) var registerCount = 0
    private(set) var createCalls: [CreateCall] = []
    private(set) var updateCalls: [UpdateCall] = []

    init(
        registerError: Error? = nil,
        createError: Error? = nil,
        updateError: Error? = nil
    ) {
        self.registerError = registerError
        self.createError = createError
        self.updateError = updateError
    }

    func registerClient(_ client: SDKClient) async throws {
        registerCount += 1
        if let registerError {
            throw registerError
        }
    }

    func createSession(
        id: String,
        name: String?,
        createdAt: Date?,
        clientID: String,
        context: ClientContext
    ) async throws {
        createCalls.append(CreateCall(id: id, clientID: clientID, context: context))
        if let createError {
            throw createError
        }
    }

    func updateSessionContext(id: String, context: ClientContext) async throws {
        updateCalls.append(UpdateCall(id: id, context: context))
        if let updateError {
            throw updateError
        }
    }
}

private actor MockRecordTransport: RecordTransport {
    private let sendError: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var sentBatches: [[NetworkRecord]] = []

    init(sendError: Error? = nil) {
        self.sendError = sendError
    }

    func start() async {
        startCount += 1
    }

    func stop() async {
        stopCount += 1
    }

    func send(records: [NetworkRecord]) async throws {
        sentBatches.append(records)
        if let sendError {
            throw sendError
        }
    }
}

private enum MockError: Error {
    case sendFailed
    case registerFailed
}

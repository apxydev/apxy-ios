import Foundation
import Testing
@testable import ApxyCore

struct WebSocketTransportTests {
    @available(iOS 13.0, macOS 10.15, *)
    @Test func webSocketURLConvertsHTTPServerURLToWS() {
        let url = WebSocketTransport.webSocketURL(for: URL(string: "http://192.168.1.5:8083")!)
        #expect(url?.absoluteString == "ws://192.168.1.5:8083/api/v1/sdk/traffic/ws")
    }

    @available(iOS 13.0, macOS 10.15, *)
    @Test func webSocketURLConvertsHTTPSServerURLToWSS() {
        let url = WebSocketTransport.webSocketURL(for: URL(string: "https://apxy.dev")!)
        #expect(url?.absoluteString == "wss://apxy.dev/api/v1/sdk/traffic/ws")
    }

    @available(iOS 13.0, macOS 10.15, *)
    @Test func webSocketURLRejectsUnsupportedSchemes() {
        #expect(WebSocketTransport.webSocketURL(for: URL(string: "ftp://apxy.dev")!) == nil)
    }

    @Test func reconnectPolicyBacksOffAndEntersCooldown() {
        var policy = WebSocketReconnectPolicy(
            initialDelay: 1,
            maxDelay: 30,
            maxAttempts: 3,
            cooldown: 60
        )

        #expect(policy.nextDecision(now: 0) == .schedule(1))
        #expect(policy.nextDecision(now: 1) == .schedule(2))
        #expect(policy.nextDecision(now: 2) == .schedule(4))
        #expect(policy.nextDecision(now: 3) == .cooldown(60))
        #expect(policy.nextDecision(now: 10) == .cooldown(53))
        #expect(policy.nextDecision(now: 63) == .schedule(1))
    }

    @Test func reconnectPolicyResetsAfterHealthySend() {
        var policy = WebSocketReconnectPolicy(
            initialDelay: 1,
            maxDelay: 30,
            maxAttempts: 5,
            cooldown: 60
        )

        #expect(policy.nextDecision(now: 0) == .schedule(1))
        #expect(policy.nextDecision(now: 1) == .schedule(2))

        policy.markHealthy()

        #expect(policy.nextDecision(now: 2) == .schedule(1))
    }
}

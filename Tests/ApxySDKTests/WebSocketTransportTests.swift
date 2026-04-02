import Foundation
import Testing
@testable import ApxySDK

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
}

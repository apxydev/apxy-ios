import Foundation

/// Mirrors the Go `NetworkRecord` domain struct sent to APXY Core.
public struct NetworkRecord: Codable, Sendable {
    public var id: String
    public var timestamp: Date
    public var method: String
    public var url: String
    public var host: String
    public var path: String
    public var requestHeaders: [String: String]?
    public var requestBody: Data?
    public var requestContentType: String?
    public var statusCode: Int
    public var responseHeaders: [String: String]?
    public var responseBody: Data?
    public var responseContentType: String?
    public var duration: Int64   // nanoseconds
    public var tls: Bool
    public var mocked: Bool
    public var sessionID: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, method, url, host, path
        case requestHeaders = "request_headers"
        case requestBody = "request_body"
        case requestContentType = "request_content_type"
        case statusCode = "status_code"
        case responseHeaders = "response_headers"
        case responseBody = "response_body"
        case responseContentType = "response_content_type"
        case duration, tls, mocked
        case sessionID = "session_id"
    }
}

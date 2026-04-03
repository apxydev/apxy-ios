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
    public var requestBodySource: String?
    public var requestBodySize: Int64?
    public var requestContentType: String?
    public var finalURL: String?
    public var finalHost: String?
    public var finalPath: String?
    public var finalRequestHeaders: [String: String]?
    public var statusCode: Int
    public var responseHeaders: [String: String]?
    public var responseBody: Data?
    public var responseBodySize: Int64?
    public var responseContentType: String?
    public var redirectCount: Int?
    public var requestHeaderBytesSent: Int64?
    public var requestBodyBytesBeforeEncoding: Int64?
    public var requestBodyBytesSent: Int64?
    public var responseHeaderBytesReceived: Int64?
    public var responseBodyBytesReceived: Int64?
    public var responseBodyBytesAfterDecoding: Int64?
    public var duration: Int64   // nanoseconds
    public var tls: Bool
    public var mocked: Bool
    public var sessionID: String?

    public init(
        id: String,
        timestamp: Date,
        method: String,
        url: String,
        host: String,
        path: String,
        requestHeaders: [String: String]? = nil,
        requestBody: Data? = nil,
        requestBodySource: String? = nil,
        requestBodySize: Int64? = nil,
        requestContentType: String? = nil,
        finalURL: String? = nil,
        finalHost: String? = nil,
        finalPath: String? = nil,
        finalRequestHeaders: [String: String]? = nil,
        statusCode: Int,
        responseHeaders: [String: String]? = nil,
        responseBody: Data? = nil,
        responseBodySize: Int64? = nil,
        responseContentType: String? = nil,
        redirectCount: Int? = nil,
        requestHeaderBytesSent: Int64? = nil,
        requestBodyBytesBeforeEncoding: Int64? = nil,
        requestBodyBytesSent: Int64? = nil,
        responseHeaderBytesReceived: Int64? = nil,
        responseBodyBytesReceived: Int64? = nil,
        responseBodyBytesAfterDecoding: Int64? = nil,
        duration: Int64,
        tls: Bool,
        mocked: Bool,
        sessionID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.url = url
        self.host = host
        self.path = path
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.requestBodySource = requestBodySource
        self.requestBodySize = requestBodySize
        self.requestContentType = requestContentType
        self.finalURL = finalURL
        self.finalHost = finalHost
        self.finalPath = finalPath
        self.finalRequestHeaders = finalRequestHeaders
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.responseBodySize = responseBodySize
        self.responseContentType = responseContentType
        self.redirectCount = redirectCount
        self.requestHeaderBytesSent = requestHeaderBytesSent
        self.requestBodyBytesBeforeEncoding = requestBodyBytesBeforeEncoding
        self.requestBodyBytesSent = requestBodyBytesSent
        self.responseHeaderBytesReceived = responseHeaderBytesReceived
        self.responseBodyBytesReceived = responseBodyBytesReceived
        self.responseBodyBytesAfterDecoding = responseBodyBytesAfterDecoding
        self.duration = duration
        self.tls = tls
        self.mocked = mocked
        self.sessionID = sessionID
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, method, url, host, path
        case requestHeaders = "request_headers"
        case requestBody = "request_body"
        case requestBodySource = "request_body_source"
        case requestBodySize = "request_body_size"
        case requestContentType = "request_content_type"
        case finalURL = "final_url"
        case finalHost = "final_host"
        case finalPath = "final_path"
        case finalRequestHeaders = "final_request_headers"
        case statusCode = "status_code"
        case responseHeaders = "response_headers"
        case responseBody = "response_body"
        case responseBodySize = "response_body_size"
        case responseContentType = "response_content_type"
        case redirectCount = "redirect_count"
        case requestHeaderBytesSent = "request_header_bytes_sent"
        case requestBodyBytesBeforeEncoding = "request_body_bytes_before_encoding"
        case requestBodyBytesSent = "request_body_bytes_sent"
        case responseHeaderBytesReceived = "response_header_bytes_received"
        case responseBodyBytesReceived = "response_body_bytes_received"
        case responseBodyBytesAfterDecoding = "response_body_bytes_after_decoding"
        case duration, tls, mocked
        case sessionID = "session_id"
    }
}

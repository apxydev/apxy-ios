import Foundation

struct CapturePayload: Sendable {
    let requestMethod: String
    let url: String
    let host: String
    let path: String
    let requestHeaders: [String: String]?
    let requestBody: Data?
    let requestBodySource: RequestBodyCaptureSource
    let requestBodySize: Int64?
    let requestContentType: String?
    let finalURL: String?
    let finalHost: String?
    let finalPath: String?
    let finalRequestHeaders: [String: String]?
    let statusCode: Int
    let responseHeaders: [String: String]?
    let responseBody: Data?
    let responseBodySize: Int64?
    let responseContentType: String?
    let redirectCount: Int
    let duration: Int64
    let tls: Bool
    let hadError: Bool
    let expectedResponseBodySize: Int64?
    let transferSize: TransferSizeInfo

    static func make(
        request: URLRequest,
        currentRequest: URLRequest,
        requestBody: Data?,
        requestBodySource: RequestBodyCaptureSource,
        response: HTTPURLResponse?,
        responseData: Data?,
        duration: Int64,
        redirectCount: Int,
        metrics: URLSessionTaskMetrics?,
        error: Error?
    ) -> CapturePayload? {
        guard let url = request.url,
              let host = url.host else {
            return nil
        }

        let transferSize = TransferSizeInfo(from: metrics)
        let requestBodySize = transferSize.requestBodyBytesBeforeEncoding
            ?? requestBody.map { Int64($0.count) }
            ?? contentLength(from: currentRequest)
        let expectedResponseBodySize = expectedResponseBodySize(from: response)
        let responseBodySize = transferSize.responseBodyBytesAfterDecoding
            ?? responseData.map { Int64($0.count) }
            ?? expectedResponseBodySize

        return CapturePayload(
            requestMethod: request.httpMethod ?? "GET",
            url: url.absoluteString,
            host: host,
            path: url.path.isEmpty ? "/" : url.path,
            requestHeaders: request.allHTTPHeaderFields.flatMap { $0.isEmpty ? nil : $0 },
            requestBody: requestBody,
            requestBodySource: requestBodySource,
            requestBodySize: requestBodySize,
            requestContentType: request.value(forHTTPHeaderField: "Content-Type"),
            finalURL: currentRequest.url?.absoluteString,
            finalHost: currentRequest.url?.host,
            finalPath: currentRequest.url?.path ?? (url.path.isEmpty ? "/" : url.path),
            finalRequestHeaders: currentRequest.allHTTPHeaderFields.flatMap { $0.isEmpty ? nil : $0 },
            statusCode: response?.statusCode ?? (error != nil ? -1 : 0),
            responseHeaders: response?.allHeaderFields.reduce(into: [String: String]()) { partialResult, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    partialResult[key] = value
                }
            },
            responseBody: responseData,
            responseBodySize: responseBodySize,
            responseContentType: response?.value(forHTTPHeaderField: "Content-Type"),
            redirectCount: redirectCount,
            duration: duration,
            tls: url.scheme == "https",
            hadError: error != nil,
            expectedResponseBodySize: expectedResponseBodySize,
            transferSize: transferSize
        )
    }

    private static func contentLength(from request: URLRequest) -> Int64? {
        guard let rawValue = request.value(forHTTPHeaderField: "Content-Length"),
              let contentLength = Int64(rawValue) else {
            return nil
        }

        return contentLength
    }

    private static func expectedResponseBodySize(from response: HTTPURLResponse?) -> Int64? {
        guard let response else { return nil }
        let expectedContentLength = response.expectedContentLength
        guard expectedContentLength >= 0 else { return nil }
        return expectedContentLength
    }
}

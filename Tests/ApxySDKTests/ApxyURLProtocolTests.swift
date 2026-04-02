import Foundation
import Testing
@testable import ApxySDK

struct ApxyURLProtocolTests {
    @Test func prepareCapturedRequestBodyUsesHTTPBodyWhenAvailable() {
        let body = Data("{\"hello\":\"world\"}".utf8)
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.httpBody = body
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest
        )

        #expect(captured.source == .httpBody)
        #expect(captured.data == body)
    }

    @Test func prepareCapturedRequestBodyReplaysHTTPBodyStream() throws {
        let body = Data("{\"streamed\":true}".utf8)
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest
        )
        let replayedStream = try #require(mutableRequest.httpBodyStream)

        #expect(captured.source == .httpBodyStream)
        #expect(captured.data == body)
        #expect(ApxyURLProtocol.readAllBytes(from: replayedStream) == body)
    }

    @Test func prepareCapturedRequestBodyReportsUnavailableWhenNoBodyExists() {
        let request = URLRequest(url: URL(string: "https://example.com/api")!)
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest
        )

        #expect(captured.source == .unavailable)
        #expect(captured.data == nil)
    }

    @Test func prepareCapturedRequestBodyUsesAnnotatedUploadTaskData() {
        let body = Data("{\"upload\":true}".utf8)
        let request = NSURLRequest(url: URL(string: "https://example.com/upload")!)
        let annotated = ApxyURLProtocol.annotateUploadRequest(
            request,
            bodyData: body,
            source: .uploadTaskData
        )
        let mutableRequest = (annotated as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: annotated,
            forwarding: mutableRequest
        )

        #expect(captured.source == .uploadTaskData)
        #expect(captured.data == body)
    }
}

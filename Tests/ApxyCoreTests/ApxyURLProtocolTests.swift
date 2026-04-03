import Foundation
import Testing
@testable import ApxyCore

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

    @Test func prepareCapturedRequestBodyTruncatesLargeHTTPBody() {
        let body = Data(repeating: 0x61, count: 128)
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.httpBody = body
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest,
            policy: ApxyCapturePolicy(maxRequestBodyBytes: 32)
        )

        #expect(captured.source == .httpBody)
        #expect(captured.data?.count == 32)
    }

    @Test func prepareCapturedRequestBodySkipsHTTPBodyStreamByDefault() {
        let body = Data("{\"streamed\":true}".utf8)
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest
        )

        #expect(captured.source == .httpBodyStreamSkipped)
        #expect(captured.data == nil)
        #expect(mutableRequest.httpBodyStream != nil)
    }

    @Test func prepareCapturedRequestBodyReplaysHTTPBodyStreamWhenEnabled() throws {
        let body = Data("{\"streamed\":true}".utf8)
        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        let captured = ApxyURLProtocol.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest,
            policy: ApxyCapturePolicy(captureHTTPBodyStreams: true)
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

    @Test func truncatedBodyReturnsNilWhenCaptureDisabled() {
        let body = Data("payload".utf8)
        #expect(ApxyURLProtocol.truncatedBody(from: body, maxBytes: 0) == nil)
    }
}

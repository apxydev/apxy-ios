import Foundation
import Testing
@testable import ApxyCore

struct SDKRequestSignerTests {
    @Test func canonicalStringIncludesMethodPathTimestampAndBodyHash() {
        let canonical = SDKRequestSigner.canonicalString(
            method: "post",
            path: "/api/v1/sdk/traffic",
            timestamp: "123",
            body: Data("hello".utf8)
        )

        #expect(
            canonical ==
            "POST\n/api/v1/sdk/traffic\n123\n2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    @Test func signAddsStableHeadersForProvidedTimestamp() {
        let signer = SDKRequestSigner(credentials: ApxyIngestCredentials(keyID: "sdki_test", clientSecret: "secret"))
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8083/api/v1/sdk/clients")!)
        request.httpMethod = "POST"

        signer.sign(&request, body: Data("{}".utf8), now: Date(timeIntervalSince1970: 123))

        #expect(request.value(forHTTPHeaderField: "X-Apxy-Key-Id") == "sdki_test")
        #expect(request.value(forHTTPHeaderField: "X-Apxy-Timestamp") == "123")
        #expect(request.value(forHTTPHeaderField: "X-Apxy-Signature") == "c6lI4imutS-1Uh8D0acC25ZIRe26nSymB9YApLlVTM8")
    }
}

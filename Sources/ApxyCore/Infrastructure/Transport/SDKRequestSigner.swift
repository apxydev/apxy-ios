import Foundation
import CryptoKit

struct SDKRequestSigner: Sendable {
    let credentials: ApxyIngestCredentials

    func sign(_ request: inout URLRequest, body: Data, now: Date = Date()) {
        let timestamp = String(Int64(now.timeIntervalSince1970))
        request.setValue(credentials.keyID, forHTTPHeaderField: "X-Apxy-Key-Id")
        request.setValue(timestamp, forHTTPHeaderField: "X-Apxy-Timestamp")
        request.setValue(
            Self.signature(
                secret: credentials.clientSecret,
                method: request.httpMethod ?? "GET",
                path: request.url?.path ?? "/",
                timestamp: timestamp,
                body: body
            ),
            forHTTPHeaderField: "X-Apxy-Signature"
        )
    }

    static func canonicalString(
        method: String,
        path: String,
        timestamp: String,
        body: Data
    ) -> String {
        let digest = SHA256.hash(data: body)
        let bodyHash = digest.map { String(format: "%02x", $0) }.joined()
        return [
            method.uppercased(),
            path,
            timestamp,
            bodyHash,
        ].joined(separator: "\n")
    }

    static func signature(
        secret: String,
        method: String,
        path: String,
        timestamp: String,
        body: Data
    ) -> String {
        let canonical = canonicalString(
            method: method,
            path: path,
            timestamp: timestamp,
            body: body
        )
        let key = SymmetricKey(data: Data(secret.utf8))
        let signed = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
        return Data(signed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

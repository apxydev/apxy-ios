import Foundation

/// Controls how much request and response payload data Apxy captures.
public struct ApxyCapturePolicy: Sendable, Equatable {
    /// Maximum number of request body bytes retained in captured records.
    public var maxRequestBodyBytes: Int
    /// Maximum number of response body bytes retained in captured records.
    public var maxResponseBodyBytes: Int
    /// When enabled, `httpBodyStream` payloads are fully read and replayed so a
    /// bounded prefix can be captured. Disabled by default to avoid hot-path I/O.
    public var captureHTTPBodyStreams: Bool
    /// When enabled, upload-task file bodies are synchronously sampled from disk.
    /// Disabled by default to avoid request-time file reads.
    public var captureUploadFileBodies: Bool

    public init(
        maxRequestBodyBytes: Int = 64 * 1024,
        maxResponseBodyBytes: Int = 64 * 1024,
        captureHTTPBodyStreams: Bool = false,
        captureUploadFileBodies: Bool = false
    ) {
        self.maxRequestBodyBytes = max(0, maxRequestBodyBytes)
        self.maxResponseBodyBytes = max(0, maxResponseBodyBytes)
        self.captureHTTPBodyStreams = captureHTTPBodyStreams
        self.captureUploadFileBodies = captureUploadFileBodies
    }

    public static let performanceFirst = ApxyCapturePolicy()
}

import Foundation

enum RequestBodyCaptureSource: String {
    case httpBody
    case httpBodyStream
    case httpBodyStreamSkipped
    case uploadTaskData
    case uploadTaskFile
    case uploadTaskFileSkipped
    case unavailable
    case streamReadFailed
}

struct CapturedRequestBody: Equatable {
    let data: Data?
    let source: RequestBodyCaptureSource
}

/// Manual URLProtocol interceptor. Register via `URLProtocol.registerClass(ApxyURLProtocol.self)`
/// or by adding `ApxyURLProtocol.self` to `URLSessionConfiguration.protocolClasses`.
///
/// Used as an explicit opt-in when method swizzling is unavailable or unwanted,
/// especially for custom `URLSessionConfiguration` instances.
public final class ApxyURLProtocol: URLProtocol, @unchecked Sendable {
    // Internal header key used to mark SDK-originated requests so they are
    // excluded from capture and avoid infinite recursion.
    static let sdkInternalKey = "X-Apxy-SDK-Internal"
    static let uploadBodyDataPropertyKey = "dev.apxy.sdk.captured-upload-body"
    static let uploadBodySourcePropertyKey = "dev.apxy.sdk.captured-upload-body-source"

    private static let domainFilterLock = NSLock()
    nonisolated(unsafe) private static var _domainFilter: DomainFilter?
    private static let capturePolicyLock = NSLock()
    nonisolated(unsafe) private static var _capturePolicy = ApxyCapturePolicy.performanceFirst

    /// When set, only hosts matching this filter are intercepted. Cleared when the SDK stops.
    static var domainFilter: DomainFilter? {
        get {
            domainFilterLock.lock()
            defer { domainFilterLock.unlock() }
            return _domainFilter
        }
        set {
            domainFilterLock.lock()
            defer { domainFilterLock.unlock() }
            _domainFilter = newValue
        }
    }

    static var capturePolicy: ApxyCapturePolicy {
        get {
            capturePolicyLock.lock()
            defer { capturePolicyLock.unlock() }
            return _capturePolicy
        }
        set {
            capturePolicyLock.lock()
            defer { capturePolicyLock.unlock() }
            _capturePolicy = newValue
        }
    }

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var apxy: Apxy?
    private var startTime: Date = .init()
    private var responseData: Data?
    private var responseBodyLimit = 0
    private var requestBodyCapture = CapturedRequestBody(data: nil, source: .unavailable)
    private var receivedResponse: HTTPURLResponse?
    private var finalRequest: URLRequest?
    private var redirectCount = 0
    private var taskMetrics: URLSessionTaskMetrics?

    /// `URLProtocol.setProperty` mutates an `NSMutableURLRequest` in place; `URLRequest` is a value type.
    private static func mutableCopy(of request: URLRequest) -> NSMutableURLRequest {
        (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
    }

    static func prepareCapturedRequestBody(
        from request: URLRequest,
        forwarding mutableRequest: NSMutableURLRequest,
        policy: ApxyCapturePolicy = .performanceFirst
    ) -> CapturedRequestBody {
        if let captured = capturedUploadBody(from: request) {
            return captured
        }
        if let body = request.httpBody {
            return CapturedRequestBody(
                data: truncatedBody(from: body, maxBytes: policy.maxRequestBodyBytes),
                source: .httpBody
            )
        }

        guard let bodyStream = request.httpBodyStream else {
            return CapturedRequestBody(data: nil, source: .unavailable)
        }

        guard policy.captureHTTPBodyStreams else {
            return CapturedRequestBody(data: nil, source: .httpBodyStreamSkipped)
        }

        guard let data = readAllBytes(from: bodyStream) else {
            return CapturedRequestBody(data: nil, source: .streamReadFailed)
        }

        mutableRequest.httpBodyStream = InputStream(data: data)
        return CapturedRequestBody(
            data: truncatedBody(from: data, maxBytes: policy.maxRequestBodyBytes),
            source: .httpBodyStream
        )
    }

    static func annotateUploadRequest(
        _ request: NSURLRequest,
        bodyData: Data?,
        source: RequestBodyCaptureSource
    ) -> URLRequest {
        guard let mutableRequest = request.mutableCopy() as? NSMutableURLRequest else {
            return request as URLRequest
        }

        if let bodyData {
            URLProtocol.setProperty(bodyData, forKey: uploadBodyDataPropertyKey, in: mutableRequest)
        }
        URLProtocol.setProperty(source.rawValue, forKey: uploadBodySourcePropertyKey, in: mutableRequest)
        return mutableRequest as URLRequest
    }

    private static func capturedUploadBody(from request: URLRequest) -> CapturedRequestBody? {
        guard let rawSource = URLProtocol.property(forKey: uploadBodySourcePropertyKey, in: request) as? String,
              let source = RequestBodyCaptureSource(rawValue: rawSource) else {
            return nil
        }
        let data = URLProtocol.property(forKey: uploadBodyDataPropertyKey, in: request) as? Data
        return CapturedRequestBody(data: data, source: source)
    }

    static func readAllBytes(from stream: InputStream) -> Data? {
        readPrefix(from: stream, maxBytes: nil)
    }

    static func readPrefix(from stream: InputStream, maxBytes: Int?) -> Data? {
        let wasOpen = stream.streamStatus == .open || stream.streamStatus == .reading
        if !wasOpen {
            stream.open()
        }
        defer {
            if !wasOpen {
                stream.close()
            }
        }

        var data = Data()
        let chunkSize = 16 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }
        let captureLimit = maxBytes.map { max(0, $0) }

        while stream.hasBytesAvailable {
            let maxLength: Int
            if let captureLimit {
                let remaining = captureLimit - data.count
                if remaining <= 0 {
                    break
                }
                maxLength = min(chunkSize, remaining)
            } else {
                maxLength = chunkSize
            }

            let bytesRead = stream.read(buffer, maxLength: maxLength)
            if bytesRead < 0 {
                return nil
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        if let error = stream.streamError {
            SDKLogger.warn("ApxyURLProtocol failed reading request body stream: \(error.localizedDescription)")
            return nil
        }

        return data
    }

    static func truncatedBody(from data: Data?, maxBytes: Int) -> Data? {
        guard let data, maxBytes > 0 else { return nil }
        if data.count <= maxBytes {
            return data
        }
        return Data(data.prefix(maxBytes))
    }

    // MARK: URLProtocol

    public override class func canInit(with request: URLRequest) -> Bool {
        // Skip SDK-internal requests and already-handled ones.
        if URLProtocol.property(forKey: sdkInternalKey, in: request) != nil { return false }
        if request.value(forHTTPHeaderField: sdkInternalKey) == "1" { return false }

        if let filter = domainFilter {
            guard let host = request.url?.host else { return false }
            let matches = filter.matches(host: host)
            if !matches {
                SDKLogger.debug("ApxyURLProtocol skipped host=\(host) due to capturedDomains filter")
            }
            return matches
        }
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        guard let apxy = Apxy.activeInstance() else { return forwardWithoutCapture() }
        self.apxy = apxy
        let capturePolicy = Self.capturePolicy

        let mutableRequest = Self.mutableCopy(of: request)
        URLProtocol.setProperty(true, forKey: Self.sdkInternalKey, in: mutableRequest)
        let capturedRequestBody = Self.prepareCapturedRequestBody(
            from: request,
            forwarding: mutableRequest,
            policy: capturePolicy
        )
        requestBodyCapture = capturedRequestBody
        startTime = Date()
        responseBodyLimit = capturePolicy.maxResponseBodyBytes
        responseData = responseBodyLimit > 0 ? Data() : nil
        receivedResponse = nil
        finalRequest = mutableRequest as URLRequest
        redirectCount = 0
        taskMetrics = nil

        if capturedRequestBody.source == .streamReadFailed {
            SDKLogger.warn(
                "ApxyURLProtocol could not snapshot request body stream method=\(request.httpMethod ?? "GET") url=\(request.url?.absoluteString ?? "?")"
            )
        }

        SDKLogger.debug(
            "ApxyURLProtocol intercepting method=\(request.httpMethod ?? "GET") url=\(request.url?.absoluteString ?? "?") requestBodySource=\(capturedRequestBody.source.rawValue) requestBodyBytes=\(capturedRequestBody.data?.count ?? 0)"
        )

        let config = URLSessionConfiguration.default
        config.protocolClasses = []   // No protocol classes → no interception
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        dataTask = session?.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    public override func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        session = nil
    }

    private func forwardWithoutCapture() {
        SDKLogger.debug("forwardWithoutCapture: Apxy runtime is inactive")
        let mutableRequest = Self.mutableCopy(of: request)
        URLProtocol.setProperty(true, forKey: Self.sdkInternalKey, in: mutableRequest)
        let config = URLSessionConfiguration.default
        config.protocolClasses = []
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self else { return }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }
}

extension ApxyURLProtocol: URLSessionDataDelegate, URLSessionTaskDelegate {
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        receivedResponse = response as? HTTPURLResponse
        finalRequest = dataTask.currentRequest ?? finalRequest
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        appendResponseData(data)
        finalRequest = dataTask.currentRequest ?? finalRequest
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectCount += 1
        finalRequest = request
        completionHandler(request)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        taskMetrics = metrics
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finalRequest = task.currentRequest ?? finalRequest
        let duration = Int64(Date().timeIntervalSince(startTime) * 1_000_000_000)

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }

        apxy?.capture(
            request: request,
            currentRequest: finalRequest ?? request,
            requestBody: requestBodyCapture.data,
            requestBodySource: requestBodyCapture.source,
            response: receivedResponse,
            responseData: responseData?.isEmpty == false ? responseData : nil,
            duration: duration,
            redirectCount: taskMetrics?.redirectCount ?? redirectCount,
            metrics: taskMetrics,
            error: error
        )

        session.finishTasksAndInvalidate()
        self.session = nil
        dataTask = nil
    }

    private func appendResponseData(_ data: Data) {
        guard responseBodyLimit > 0 else { return }
        guard var responseData else { return }
        let remaining = responseBodyLimit - responseData.count
        guard remaining > 0 else { return }

        if data.count <= remaining {
            responseData.append(data)
        } else {
            responseData.append(data.prefix(remaining))
        }
        self.responseData = responseData
    }
}

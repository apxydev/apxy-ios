import Foundation

/// Manual URLProtocol interceptor. Register via `URLProtocol.registerClass(ApxyURLProtocol.self)`
/// or by adding `ApxyURLProtocol.self` to `URLSessionConfiguration.protocolClasses`.
///
/// Used as an explicit opt-in when method swizzling is unavailable or unwanted.
public final class ApxyURLProtocol: URLProtocol, @unchecked Sendable {
    // Internal header key used to mark SDK-originated requests so they are
    // excluded from capture and avoid infinite recursion.
    static let sdkInternalKey = "X-Apxy-SDK-Internal"

    private static let domainFilterLock = NSLock()
    private static var _domainFilter: DomainFilter?

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

    private var dataTask: URLSessionDataTask?
    private var startTime: Date = .init()
    private var responseData = Data()

    private static let internalSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.protocolClasses = []   // No protocol classes → no interception
        return URLSession(configuration: config)
    }()

    /// `URLProtocol.setProperty` mutates an `NSMutableURLRequest` in place; `URLRequest` is a value type.
    private static func mutableCopy(of request: URLRequest) -> NSMutableURLRequest {
        (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
    }

    // MARK: URLProtocol

    public override class func canInit(with request: URLRequest) -> Bool {
        // Skip SDK-internal requests and already-handled ones.
        if URLProtocol.property(forKey: sdkInternalKey, in: request) != nil { return false }
        if request.value(forHTTPHeaderField: sdkInternalKey) == "1" { return false }

        if let filter = domainFilter {
            guard let host = request.url?.host else { return false }
            return filter.matches(host: host)
        }
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        guard let apxy = Apxy.shared else { return forwardWithoutCapture() }

        let mutableRequest = Self.mutableCopy(of: request)
        URLProtocol.setProperty(true, forKey: Self.sdkInternalKey, in: mutableRequest)
        startTime = Date()
        responseData = Data()

        dataTask = Self.internalSession.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self else { return }
            let duration = Int64(Date().timeIntervalSince(self.startTime) * 1_000_000_000)

            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                if let response {
                    self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data {
                    self.responseData = data
                    self.client?.urlProtocol(self, didLoad: data)
                }
                self.client?.urlProtocolDidFinishLoading(self)
            }

            // Capture the exchange.
            apxy.capture(
                request: self.request,
                response: response as? HTTPURLResponse,
                responseData: data,
                duration: duration,
                error: error
            )
        }
        dataTask?.resume()
    }

    public override func stopLoading() {
        dataTask?.cancel()
    }

    private func forwardWithoutCapture() {
        SDKLogger.debug("forwardWithoutCapture: Apxy.shared is nil")
        let mutableRequest = Self.mutableCopy(of: request)
        URLProtocol.setProperty(true, forKey: Self.sdkInternalKey, in: mutableRequest)
        let task = Self.internalSession.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self else { return }
            if let error { self.client?.urlProtocol(self, didFailWithError: error); return }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }
}

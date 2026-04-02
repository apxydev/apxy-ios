import Foundation

/// Queries the APXY server to determine whether its proxy is currently running.
///
/// The check uses a dedicated `URLSession` whose configuration carries
/// `X-Apxy-SDK-Internal: 1`, so the request is excluded from capture by both
/// the SDK's own `ApxyURLProtocol` and the proxy's recording handler.
enum ProxyDetector {

    /// Asks `serverURL` for proxy status and calls `completion(true)` if the
    /// proxy is running, or `completion(false)` on any error or if it is stopped.
    ///
    /// - Parameters:
    ///   - serverURL: Base URL of the APXY Core instance (e.g. `http://192.168.1.5:8081`).
    ///   - completion: Called on an arbitrary background queue with the result.
    static func checkProxyRunning(serverURL: URL, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "/api/v1/sdk/proxy-status", relativeTo: serverURL) else {
            completion(false)
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "GET"
        req.setValue("1", forHTTPHeaderField: "X-Apxy-SDK-Internal")

        internalSession.dataTask(with: req) { data, response, _ in
            guard
                let data = data,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let running = json["proxy_running"] as? Bool
            else {
                completion(false)
                return
            }
            completion(running)
        }.resume()
    }

    // MARK: - Private

    /// A non-intercepted session. `protocolClasses = []` prevents the SDK's own
    /// `ApxyURLProtocol` from intercepting this request; the SDK-internal header
    /// prevents the proxy's request handler from recording it.
    private static let internalSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        config.httpAdditionalHeaders = ["X-Apxy-SDK-Internal": "1"]
        return URLSession(configuration: config)
    }()
}

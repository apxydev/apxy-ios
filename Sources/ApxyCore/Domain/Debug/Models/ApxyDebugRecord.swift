import Foundation

/// Rich local debug model used by the embedded Apxy console.
public struct ApxyDebugRecord: Codable, Sendable, Hashable, Identifiable {
    public struct Request: Codable, Sendable, Hashable {
        public var method: String
        public var url: String
        public var host: String
        public var path: String
        public var headers: [String: String]
        public var body: Data?
        public var bodySize: Int64?
        public var contentType: String?
        public var currentURL: String?
        public var currentHost: String?
        public var currentPath: String?
        public var currentHeaders: [String: String]

        public init(
            method: String,
            url: String,
            host: String,
            path: String,
            headers: [String: String],
            body: Data?,
            bodySize: Int64?,
            contentType: String?,
            currentURL: String?,
            currentHost: String?,
            currentPath: String?,
            currentHeaders: [String: String]
        ) {
            self.method = method
            self.url = url
            self.host = host
            self.path = path
            self.headers = headers
            self.body = body
            self.bodySize = bodySize
            self.contentType = contentType
            self.currentURL = currentURL
            self.currentHost = currentHost
            self.currentPath = currentPath
            self.currentHeaders = currentHeaders
        }
    }

    public struct Response: Codable, Sendable, Hashable {
        public var statusCode: Int
        public var headers: [String: String]
        public var body: Data?
        public var bodySize: Int64?
        public var contentType: String?

        public init(
            statusCode: Int,
            headers: [String: String],
            body: Data?,
            bodySize: Int64?,
            contentType: String?
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
            self.bodySize = bodySize
            self.contentType = contentType
        }
    }

    public struct ErrorInfo: Codable, Sendable, Hashable {
        public var domain: String
        public var code: Int
        public var message: String

        public init(domain: String, code: Int, message: String) {
            self.domain = domain
            self.code = code
            self.message = message
        }
    }

    public struct TransferMetrics: Codable, Sendable, Hashable {
        public var requestHeaderBytesSent: Int64?
        public var requestBodyBytesBeforeEncoding: Int64?
        public var requestBodyBytesSent: Int64?
        public var responseHeaderBytesReceived: Int64?
        public var responseBodyBytesReceived: Int64?
        public var responseBodyBytesAfterDecoding: Int64?

        public init(
            requestHeaderBytesSent: Int64?,
            requestBodyBytesBeforeEncoding: Int64?,
            requestBodyBytesSent: Int64?,
            responseHeaderBytesReceived: Int64?,
            responseBodyBytesReceived: Int64?,
            responseBodyBytesAfterDecoding: Int64?
        ) {
            self.requestHeaderBytesSent = requestHeaderBytesSent
            self.requestBodyBytesBeforeEncoding = requestBodyBytesBeforeEncoding
            self.requestBodyBytesSent = requestBodyBytesSent
            self.responseHeaderBytesReceived = responseHeaderBytesReceived
            self.responseBodyBytesReceived = responseBodyBytesReceived
            self.responseBodyBytesAfterDecoding = responseBodyBytesAfterDecoding
        }
    }

    public struct Metrics: Codable, Sendable, Hashable {
        public struct Transaction: Codable, Sendable, Hashable, Identifiable {
            public var id: UUID
            public var fetchType: String
            public var requestURL: String?
            public var responseStatusCode: Int?
            public var networkProtocolName: String?
            public var localAddress: String?
            public var remoteAddress: String?
            public var localPort: Int?
            public var remotePort: Int?
            public var reusedConnection: Bool
            public var proxyConnection: Bool
            public var resourceFetchStart: Date?
            public var domainLookupStart: Date?
            public var domainLookupEnd: Date?
            public var connectStart: Date?
            public var secureConnectionStart: Date?
            public var secureConnectionEnd: Date?
            public var connectEnd: Date?
            public var requestStart: Date?
            public var requestEnd: Date?
            public var responseStart: Date?
            public var responseEnd: Date?
            public var transfer: TransferMetrics

            public init(
                id: UUID = UUID(),
                fetchType: String,
                requestURL: String?,
                responseStatusCode: Int?,
                networkProtocolName: String?,
                localAddress: String?,
                remoteAddress: String?,
                localPort: Int?,
                remotePort: Int?,
                reusedConnection: Bool,
                proxyConnection: Bool,
                resourceFetchStart: Date?,
                domainLookupStart: Date?,
                domainLookupEnd: Date?,
                connectStart: Date?,
                secureConnectionStart: Date?,
                secureConnectionEnd: Date?,
                connectEnd: Date?,
                requestStart: Date?,
                requestEnd: Date?,
                responseStart: Date?,
                responseEnd: Date?,
                transfer: TransferMetrics
            ) {
                self.id = id
                self.fetchType = fetchType
                self.requestURL = requestURL
                self.responseStatusCode = responseStatusCode
                self.networkProtocolName = networkProtocolName
                self.localAddress = localAddress
                self.remoteAddress = remoteAddress
                self.localPort = localPort
                self.remotePort = remotePort
                self.reusedConnection = reusedConnection
                self.proxyConnection = proxyConnection
                self.resourceFetchStart = resourceFetchStart
                self.domainLookupStart = domainLookupStart
                self.domainLookupEnd = domainLookupEnd
                self.connectStart = connectStart
                self.secureConnectionStart = secureConnectionStart
                self.secureConnectionEnd = secureConnectionEnd
                self.connectEnd = connectEnd
                self.requestStart = requestStart
                self.requestEnd = requestEnd
                self.responseStart = responseStart
                self.responseEnd = responseEnd
                self.transfer = transfer
            }
        }

        public var taskInterval: DateInterval
        public var redirectCount: Int
        public var transactions: [Transaction]

        public init(taskInterval: DateInterval, redirectCount: Int, transactions: [Transaction]) {
            self.taskInterval = taskInterval
            self.redirectCount = redirectCount
            self.transactions = transactions
        }
    }

    public var id: String
    public var capturedAt: Date
    public var sessionID: String?
    public var request: Request
    public var response: Response?
    public var transfer: TransferMetrics
    public var metrics: Metrics?
    public var error: ErrorInfo?
    public var redirectCount: Int
    public var duration: TimeInterval
    public var isTLS: Bool
    public var isMocked: Bool

    public init(
        id: String,
        capturedAt: Date,
        sessionID: String?,
        request: Request,
        response: Response?,
        transfer: TransferMetrics,
        metrics: Metrics?,
        error: ErrorInfo?,
        redirectCount: Int,
        duration: TimeInterval,
        isTLS: Bool,
        isMocked: Bool
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.sessionID = sessionID
        self.request = request
        self.response = response
        self.transfer = transfer
        self.metrics = metrics
        self.error = error
        self.redirectCount = redirectCount
        self.duration = duration
        self.isTLS = isTLS
        self.isMocked = isMocked
    }

    public var isFailure: Bool {
        if error != nil {
            return true
        }
        if let response {
            return response.statusCode >= 400 || response.statusCode < 0
        }
        return false
    }
}

public struct ApxyDebugSession: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var startedAt: Date
    public var lastEventAt: Date
    public var requestCount: Int
    public var failureCount: Int
    public var syncState: ApxyLocalSessionSyncState

    public var isShareable: Bool {
        switch syncState {
        case .localOnly, .synced, .failed: return true
        case .liveManaged, .syncing: return false
        }
    }

    public init(
        id: String,
        startedAt: Date,
        lastEventAt: Date,
        requestCount: Int,
        failureCount: Int,
        syncState: ApxyLocalSessionSyncState = .localOnly
    ) {
        self.id = id
        self.startedAt = startedAt
        self.lastEventAt = lastEventAt
        self.requestCount = requestCount
        self.failureCount = failureCount
        self.syncState = syncState
    }
}

public struct ApxyDebugSnapshot: Sendable, Hashable {
    public var records: [ApxyDebugRecord]
    public var sessions: [ApxyDebugSession]

    public init(records: [ApxyDebugRecord], sessions: [ApxyDebugSession]) {
        self.records = records
        self.sessions = sessions
    }

    public static let empty = ApxyDebugSnapshot(records: [], sessions: [])
}

extension ApxyDebugRecord {
    static func make(
        record: NetworkRecord,
        metrics: Metrics?,
        error: ErrorInfo?
    ) -> ApxyDebugRecord {
        let requestModel = Request(
            method: record.method,
            url: record.url,
            host: record.host,
            path: record.path,
            headers: record.requestHeaders ?? [:],
            body: record.requestBody,
            bodySize: record.requestBodySize,
            contentType: record.requestContentType,
            currentURL: record.finalURL,
            currentHost: record.finalHost,
            currentPath: record.finalPath,
            currentHeaders: record.finalRequestHeaders ?? [:]
        )

        let responseModel: Response? = {
            let hasResponse = record.statusCode > 0
                || record.responseBody != nil
                || record.responseBodySize != nil
                || record.responseContentType != nil
                || record.responseHeaders?.isEmpty == false
            guard hasResponse else { return nil }
            return Response(
                statusCode: record.statusCode,
                headers: record.responseHeaders ?? [:],
                body: record.responseBody,
                bodySize: record.responseBodySize,
                contentType: record.responseContentType
            )
        }()

        return ApxyDebugRecord(
            id: record.id,
            capturedAt: record.timestamp,
            sessionID: record.sessionID,
            request: requestModel,
            response: responseModel,
            transfer: TransferMetrics(record),
            metrics: metrics,
            error: error,
            redirectCount: record.redirectCount ?? 0,
            duration: Double(record.duration) / 1_000_000_000,
            isTLS: record.tls,
            isMocked: record.mocked
        )
    }
}

private extension ApxyDebugRecord.TransferMetrics {
    init(_ record: NetworkRecord) {
        self.init(
            requestHeaderBytesSent: record.requestHeaderBytesSent,
            requestBodyBytesBeforeEncoding: record.requestBodyBytesBeforeEncoding,
            requestBodyBytesSent: record.requestBodyBytesSent,
            responseHeaderBytesReceived: record.responseHeaderBytesReceived,
            responseBodyBytesReceived: record.responseBodyBytesReceived,
            responseBodyBytesAfterDecoding: record.responseBodyBytesAfterDecoding
        )
    }
}

extension ApxyDebugRecord.Metrics {
    init(_ metrics: URLSessionTaskMetrics) {
        self.init(
            taskInterval: metrics.taskInterval,
            redirectCount: metrics.redirectCount,
            transactions: metrics.transactionMetrics.map(Transaction.init)
        )
    }
}

private extension ApxyDebugRecord.Metrics.Transaction {
    init(_ transaction: URLSessionTaskTransactionMetrics) {
        let fetchType: String
        switch transaction.resourceFetchType {
        case .networkLoad:
            fetchType = "network"
        case .serverPush:
            fetchType = "serverPush"
        case .localCache:
            fetchType = "localCache"
        case .unknown:
            fetchType = "unknown"
        @unknown default:
            fetchType = "other"
        }

        self.init(
            fetchType: fetchType,
            requestURL: transaction.request.url?.absoluteString,
            responseStatusCode: (transaction.response as? HTTPURLResponse)?.statusCode,
            networkProtocolName: transaction.networkProtocolName,
            localAddress: transaction.localAddress,
            remoteAddress: transaction.remoteAddress,
            localPort: transaction.localPort,
            remotePort: transaction.remotePort,
            reusedConnection: transaction.isReusedConnection,
            proxyConnection: transaction.isProxyConnection,
            resourceFetchStart: transaction.fetchStartDate,
            domainLookupStart: transaction.domainLookupStartDate,
            domainLookupEnd: transaction.domainLookupEndDate,
            connectStart: transaction.connectStartDate,
            secureConnectionStart: transaction.secureConnectionStartDate,
            secureConnectionEnd: transaction.secureConnectionEndDate,
            connectEnd: transaction.connectEndDate,
            requestStart: transaction.requestStartDate,
            requestEnd: transaction.requestEndDate,
            responseStart: transaction.responseStartDate,
            responseEnd: transaction.responseEndDate,
            transfer: ApxyDebugRecord.TransferMetrics(
                requestHeaderBytesSent: transaction.countOfRequestHeaderBytesSent,
                requestBodyBytesBeforeEncoding: transaction.countOfRequestBodyBytesBeforeEncoding,
                requestBodyBytesSent: transaction.countOfRequestBodyBytesSent,
                responseHeaderBytesReceived: transaction.countOfResponseHeaderBytesReceived,
                responseBodyBytesReceived: transaction.countOfResponseBodyBytesReceived,
                responseBodyBytesAfterDecoding: transaction.countOfResponseBodyBytesAfterDecoding
            )
        )
    }
}

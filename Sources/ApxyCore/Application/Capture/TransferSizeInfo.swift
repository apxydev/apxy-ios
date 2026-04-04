import Foundation

struct TransferSizeInfo: Sendable {
    let requestHeaderBytesSent: Int64?
    let requestBodyBytesBeforeEncoding: Int64?
    let requestBodyBytesSent: Int64?
    let responseHeaderBytesReceived: Int64?
    let responseBodyBytesReceived: Int64?
    let responseBodyBytesAfterDecoding: Int64?

    init(from metrics: URLSessionTaskMetrics?) {
        guard let metrics else {
            self = .empty
            return
        }

        self = metrics.transactionMetrics.reduce(.empty) { partialResult, transaction in
            partialResult.merging(TransferSizeInfo(transaction: transaction))
        }
    }

    static let empty = TransferSizeInfo(
        requestHeaderBytesSent: nil,
        requestBodyBytesBeforeEncoding: nil,
        requestBodyBytesSent: nil,
        responseHeaderBytesReceived: nil,
        responseBodyBytesReceived: nil,
        responseBodyBytesAfterDecoding: nil
    )

    init(
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

    init(transaction: URLSessionTaskTransactionMetrics) {
        requestHeaderBytesSent = transaction.countOfRequestHeaderBytesSent
        requestBodyBytesBeforeEncoding = transaction.countOfRequestBodyBytesBeforeEncoding
        requestBodyBytesSent = transaction.countOfRequestBodyBytesSent
        responseHeaderBytesReceived = transaction.countOfResponseHeaderBytesReceived
        responseBodyBytesReceived = transaction.countOfResponseBodyBytesReceived
        responseBodyBytesAfterDecoding = transaction.countOfResponseBodyBytesAfterDecoding
    }

    func merging(_ other: TransferSizeInfo) -> TransferSizeInfo {
        TransferSizeInfo(
            requestHeaderBytesSent: sum(requestHeaderBytesSent, other.requestHeaderBytesSent),
            requestBodyBytesBeforeEncoding: sum(requestBodyBytesBeforeEncoding, other.requestBodyBytesBeforeEncoding),
            requestBodyBytesSent: sum(requestBodyBytesSent, other.requestBodyBytesSent),
            responseHeaderBytesReceived: sum(responseHeaderBytesReceived, other.responseHeaderBytesReceived),
            responseBodyBytesReceived: sum(responseBodyBytesReceived, other.responseBodyBytesReceived),
            responseBodyBytesAfterDecoding: sum(responseBodyBytesAfterDecoding, other.responseBodyBytesAfterDecoding)
        )
    }

    private func sum(_ lhs: Int64?, _ rhs: Int64?) -> Int64? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            lhs &+ rhs
        case let (lhs?, nil):
            lhs
        case let (nil, rhs?):
            rhs
        case (nil, nil):
            nil
        }
    }
}

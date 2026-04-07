import Foundation
import ApxyCore

enum ApxyDebugStatusFilter: String, CaseIterable, Sendable {
    case all
    case failures
    case successes

    var title: String {
        switch self {
        case .all:
            "All"
        case .failures:
            "Failures"
        case .successes:
            "Successes"
        }
    }
}

struct ApxyDebugConsoleFilter: Sendable, Equatable {
    var searchText: String = ""
    var status: ApxyDebugStatusFilter = .all
    var sessionID: String?
    var method: String?
}

enum ApxyDebugFilterEngine {
    static func filter(records: [ApxyDebugRecord], using filter: ApxyDebugConsoleFilter) -> [ApxyDebugRecord] {
        records.filter { record in
            matchesStatus(record, status: filter.status)
                && matchesSession(record, sessionID: filter.sessionID)
                && matchesMethod(record, method: filter.method)
                && matchesSearch(record, query: filter.searchText)
        }
    }

    private static func matchesStatus(_ record: ApxyDebugRecord, status: ApxyDebugStatusFilter) -> Bool {
        switch status {
        case .all:
            true
        case .failures:
            record.isFailure
        case .successes:
            !record.isFailure
        }
    }

    private static func matchesSession(_ record: ApxyDebugRecord, sessionID: String?) -> Bool {
        guard let sessionID, !sessionID.isEmpty else { return true }
        return record.sessionID == sessionID
    }

    private static func matchesMethod(_ record: ApxyDebugRecord, method: String?) -> Bool {
        guard let method, !method.isEmpty else { return true }
        return record.request.method == method
    }

    private static func matchesSearch(_ record: ApxyDebugRecord, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        // Check cheap fields first (URL, host, method, path)
        let cheapFields = [
            record.request.method,
            record.request.url,
            record.request.host,
            record.request.path,
            record.request.currentURL ?? ""
        ]
        if cheapFields.contains(where: { $0.localizedStandardContains(trimmed) }) {
            return true
        }

        // Then headers
        if headerString(record.request.headers).localizedStandardContains(trimmed) { return true }
        if headerString(record.request.currentHeaders).localizedStandardContains(trimmed) { return true }

        // Expensive: body text last
        if ApxyDebugBodyFormatter.searchableText(
            data: record.request.body,
            contentType: record.request.contentType
        ).localizedStandardContains(trimmed) {
            return true
        }

        if let response = record.response {
            if headerString(response.headers).localizedStandardContains(trimmed) { return true }
            if ApxyDebugBodyFormatter.searchableText(
                data: response.body,
                contentType: response.contentType
            ).localizedStandardContains(trimmed) {
                return true
            }
        }

        if record.error?.message.localizedStandardContains(trimmed) == true { return true }

        return false
    }

    private static func headerString(_ headers: [String: String]) -> String {
        headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}

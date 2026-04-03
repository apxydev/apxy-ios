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
    var host: String?
    var method: String?
}

enum ApxyDebugFilterEngine {
    static func filter(records: [ApxyDebugRecord], using filter: ApxyDebugConsoleFilter) -> [ApxyDebugRecord] {
        records.filter { record in
            matchesStatus(record, status: filter.status)
                && matchesSession(record, sessionID: filter.sessionID)
                && matchesHost(record, host: filter.host)
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

    private static func matchesHost(_ record: ApxyDebugRecord, host: String?) -> Bool {
        guard let host, !host.isEmpty else { return true }
        return record.request.host == host
    }

    private static func matchesMethod(_ record: ApxyDebugRecord, method: String?) -> Bool {
        guard let method, !method.isEmpty else { return true }
        return record.request.method == method
    }

    private static func matchesSearch(_ record: ApxyDebugRecord, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let normalized = trimmed.lowercased()

        return searchableValues(for: record).contains { value in
            value.localizedCaseInsensitiveContains(normalized)
        }
    }

    private static func searchableValues(for record: ApxyDebugRecord) -> [String] {
        [
            record.request.method,
            record.request.url,
            record.request.host,
            record.request.path,
            record.request.currentURL ?? "",
            headerString(record.request.headers),
            headerString(record.request.currentHeaders),
            ApxyDebugBodyFormatter.searchableText(data: record.request.body, contentType: record.request.contentType),
            record.response.map { headerString($0.headers) } ?? "",
            ApxyDebugBodyFormatter.searchableText(
                data: record.response?.body,
                contentType: record.response?.contentType
            ),
            record.error?.message ?? ""
        ]
    }

    private static func headerString(_ headers: [String: String]) -> String {
        headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}

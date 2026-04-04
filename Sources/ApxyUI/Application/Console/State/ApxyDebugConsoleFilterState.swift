import Foundation

struct ApxyDebugConsoleFilterState: Equatable {
    var searchText: String = ""
    var status: ApxyDebugStatusFilter = .all
    var selectedSessionID: String?
    var selectedHost: String?
    var selectedMethod: String?

    var activeFilterItems: [ApxyDebugConsoleActiveFilterItem] {
        var items: [ApxyDebugConsoleActiveFilterItem] = []
        if status != .all {
            items.append(.init(kind: .status, title: status.title))
        }
        if let selectedSessionID, !selectedSessionID.isEmpty {
            items.append(.init(kind: .session, title: "Session \(String(selectedSessionID.prefix(8)))"))
        }
        if let selectedHost, !selectedHost.isEmpty {
            items.append(.init(kind: .host, title: selectedHost))
        }
        if let selectedMethod, !selectedMethod.isEmpty {
            items.append(.init(kind: .method, title: selectedMethod))
        }
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            items.append(.init(kind: .search, title: "\"\(trimmedSearch)\""))
        }
        return items
    }

    var consoleFilter: ApxyDebugConsoleFilter {
        ApxyDebugConsoleFilter(
            searchText: searchText,
            status: status,
            sessionID: selectedSessionID,
            host: selectedHost,
            method: selectedMethod
        )
    }

    mutating func clear(_ kind: ApxyDebugConsoleActiveFilterItem.Kind) {
        switch kind {
        case .status:
            status = .all
        case .session:
            selectedSessionID = nil
        case .host:
            selectedHost = nil
        case .method:
            selectedMethod = nil
        case .search:
            searchText = ""
        }
    }
}

import Foundation

struct ApxyDebugConsoleActiveFilterItem: Identifiable, Equatable {
    enum Kind {
        case status
        case session
        case host
        case method
        case search
    }

    let kind: Kind
    let title: String

    var id: String { "\(kind)-\(title)" }
}

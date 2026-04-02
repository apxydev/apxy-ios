import Foundation

/// In-memory state that tracks the current session's user/tags/context.
struct SessionContext: Sendable {
    private(set) var currentUser: ApxyUser?
    private(set) var tags: [String: String] = [:]
    private(set) var context: [String: ApxyContextValue] = [:]

    mutating func setUser(_ user: ApxyUser) {
        currentUser = user
    }

    mutating func setTag(key: String, value: String) {
        tags[key] = value
    }

    mutating func setContext(key: String, value: ApxyContextValue) {
        context[key] = value
    }

    func toClientContext(networkType: String?) -> ClientContext {
        ClientContext(
            userID: currentUser?.id,
            userEmail: currentUser?.email,
            userName: currentUser?.name,
            networkType: networkType,
            tags: tags.isEmpty ? nil : tags,
            context: context.isEmpty ? nil : context
        )
    }

    mutating func reset() {
        currentUser = nil
        tags.removeAll()
        context.removeAll()
    }
}

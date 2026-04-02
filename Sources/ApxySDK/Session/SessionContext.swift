import Foundation

/// Mutable in-memory state that tracks the current session's user/tags/context.
/// All mutations happen on the SDK's internal serial queue — no external locking needed.
final class SessionContext: @unchecked Sendable {
    private(set) var currentUser: ApxyUser?
    private(set) var tags: [String: String] = [:]
    private(set) var context: [String: AnyCodable] = [:]

    func setUser(_ user: ApxyUser) {
        currentUser = user
    }

    func setTag(key: String, value: String) {
        tags[key] = value
    }

    func setContext(key: String, value: AnyCodable) {
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

    func reset() {
        currentUser = nil
        tags.removeAll()
        context.removeAll()
    }
}

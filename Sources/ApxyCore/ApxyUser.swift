import Foundation

/// User identity information attached to the current SDK session.
public struct ApxyUser: Sendable {
    public let id: String?
    public let email: String?
    public let name: String?

    public init(id: String? = nil, email: String? = nil, name: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
    }
}

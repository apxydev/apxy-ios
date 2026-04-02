import Foundation

/// Mirrors the Go `SessionClientContext` struct.
/// Sent as the body of `POST /api/v1/sdk/sessions` and `PATCH /api/v1/sdk/sessions/:id`.
public struct ClientContext: Codable, Sendable {
    public var userID: String?
    public var userEmail: String?
    public var userName: String?
    public var networkType: String?
    public var tags: [String: String]?
    public var context: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case userEmail = "user_email"
        case userName = "user_name"
        case networkType = "network_type"
        case tags, context
    }

    public init(
        userID: String? = nil,
        userEmail: String? = nil,
        userName: String? = nil,
        networkType: String? = nil,
        tags: [String: String]? = nil,
        context: [String: AnyCodable]? = nil
    ) {
        self.userID = userID
        self.userEmail = userEmail
        self.userName = userName
        self.networkType = networkType
        self.tags = tags
        self.context = context
    }
}

// ---------------------------------------------------------------------------
// AnyCodable — lightweight type-erased Codable for arbitrary JSON values
// ---------------------------------------------------------------------------

public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else { value = NSNull() }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:   try container.encode(v)
        case let v as Int:    try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]:         try container.encode(v)
        default: try container.encodeNil()
        }
    }
}

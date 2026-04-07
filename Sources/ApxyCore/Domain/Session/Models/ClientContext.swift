import Foundation

/// Mirrors the Go `SessionClientContext` struct.
/// Sent as the body of `POST /api/v1/sdk/sessions` and `PATCH /api/v1/sdk/sessions/:id`.
public struct ClientContext: Codable, Sendable, Equatable {
    public var userID: String?
    public var userEmail: String?
    public var userName: String?
    public var networkType: String?
    public var tags: [String: String]?
    public var context: [String: ApxyContextValue]?

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
        context: [String: ApxyContextValue]? = nil
    ) {
        self.userID = userID
        self.userEmail = userEmail
        self.userName = userName
        self.networkType = networkType
        self.tags = tags
        self.context = context
    }
}

public enum ApxyContextValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([ApxyContextValue])
    case object([String: ApxyContextValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ApxyContextValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([ApxyContextValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported APXY context value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    static func make(from value: Any) -> ApxyContextValue? {
        switch value {
        case is NSNull:
            return .null
        case let value as ApxyContextValue:
            return value
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .integer(value)
        case let value as Double:
            return .double(value)
        case let value as Float:
            return .double(Double(value))
        case let value as String:
            return .string(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }

            let doubleValue = value.doubleValue
            let intValue = value.intValue
            if Double(intValue) == doubleValue {
                return .integer(intValue)
            }
            return .double(doubleValue)
        case let value as [String: Any]:
            let converted = value.reduce(into: [String: ApxyContextValue]()) { partialResult, entry in
                guard let nested = make(from: entry.value) else { return }
                partialResult[entry.key] = nested
            }
            return converted.count == value.count ? .object(converted) : nil
        case let value as [Any]:
            let converted = value.compactMap(make(from:))
            return converted.count == value.count ? .array(converted) : nil
        default:
            return nil
        }
    }
}

extension ApxyContextValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension ApxyContextValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension ApxyContextValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension ApxyContextValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension ApxyContextValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension ApxyContextValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ApxyContextValue...) {
        self = .array(elements)
    }
}

extension ApxyContextValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, ApxyContextValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

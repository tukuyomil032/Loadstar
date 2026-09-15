import Foundation

public enum DocumentType: String, Codable, Sendable {
    case appState = "app-state"
    case serverIndex = "server-index"
    case serverMetadata = "server-metadata"
    case operation = "operation"
    case backupCatalog = "backup-catalog"
}

public struct SchemaVersion: Codable, Hashable, Sendable {
    public let documentType: DocumentType
    public let revision: Int

    public init(documentType: DocumentType, revision: Int) throws {
        guard revision > 0 else {
            throw DomainValidationError.invalidSchemaRevision(revision)
        }

        self.documentType = documentType
        self.revision = revision
    }
}

public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case boolean(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            guard value.isFinite else {
                throw DomainValidationError.nonFiniteJSONNumber
            }
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DomainValidationError.invalidJSONValue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .boolean(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .number(let value):
            guard value.isFinite else {
                throw DomainValidationError.nonFiniteJSONNumber
            }
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

public typealias UnknownFields = [String: JSONValue]

public protocol LoadStarDocumentPayload: Codable, Sendable {
    static var documentType: DocumentType { get }
    static var currentSchemaRevision: Int { get }

    func validate() throws
}

public struct LoadStarDocument<Payload: Codable & Sendable>: Codable, Sendable {
    public let documentType: DocumentType
    public let schemaVersion: SchemaVersion
    public var payload: Payload
    public var unknownFields: UnknownFields

    public init(
        documentType: DocumentType,
        revision: Int,
        payload: Payload,
        unknownFields: UnknownFields = [:]
    ) throws {
        self.documentType = documentType
        self.schemaVersion = try SchemaVersion(documentType: documentType, revision: revision)
        self.payload = payload
        self.unknownFields = unknownFields
    }
}

public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock, Sendable {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

import Foundation

public enum LoadStarDomain: Sendable {
    public static let productName = "LoadStar"
}

public struct ServerID: Hashable, Codable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(uuid: UUID) {
        self.rawValue = uuid.uuidString.lowercased()
    }

    public init(validating rawValue: String) throws {
        guard let uuid = UUID(uuidString: rawValue) else {
            throw DomainValidationError.invalidServerID(rawValue)
        }

        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        guard bytes.count == 16, bytes[6] & 0xf0 == 0x40 else {
            throw DomainValidationError.invalidServerID(rawValue)
        }

        self.init(uuid: uuid)
    }

    public static func new() -> Self {
        Self(uuid: UUID())
    }
}

public enum LoadStarDomain: Sendable {
    public static let productName = "LoadStar"
}

public struct ServerID: Hashable, Codable, RawRepresentable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

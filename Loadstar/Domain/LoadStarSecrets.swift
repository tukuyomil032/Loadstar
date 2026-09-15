import Foundation

public enum SecretPurpose: String, Codable, Hashable, Sendable {
    case ngrokToken
    case proxyForwardingSecret
    case providerCredential
    case custom
}

public struct SecretKey: Codable, Hashable, Sendable {
    public let namespace: StorageNamespace
    public let serverID: ServerID?
    public let purpose: SecretPurpose
    public let identifier: String?

    public init(
        namespace: StorageNamespace,
        serverID: ServerID? = nil,
        purpose: SecretPurpose,
        identifier: String? = nil
    ) {
        self.namespace = namespace
        self.serverID = serverID
        self.purpose = purpose
        self.identifier = identifier
    }
}

public struct SecretValue: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private let bytes: Data

    public init(data: Data) {
        self.bytes = data
    }

    public var description: String {
        "<redacted>"
    }

    public var debugDescription: String {
        "<redacted>"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [:], displayStyle: .struct)
    }

    public func withData<Result>(_ body: (Data) throws -> Result) rethrows -> Result {
        try body(bytes)
    }
}

public protocol KeychainClient: Sendable {
    func read(for key: SecretKey) async throws -> SecretValue?
    func write(_ value: SecretValue, for key: SecretKey) async throws
    func delete(for key: SecretKey) async throws
}

import Foundation
import LoadStarDomain
import Security

public enum KeychainServiceError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
}

public final class KeychainService: KeychainClient, @unchecked Sendable {
    public init() {}

    public func read(for key: SecretKey) async throws -> SecretValue? {
        var query = baseQuery(for: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainServiceError.unexpectedStatus(status)
        }
        return SecretValue(data: data)
    }

    public func write(_ value: SecretValue, for key: SecretKey) async throws {
        var query = baseQuery(for: key)
        let data = value.withData { $0 }
        var attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainServiceError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        attributes = query
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainServiceError.unexpectedStatus(addStatus)
        }
    }

    public func delete(for key: SecretKey) async throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainServiceError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: SecretKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.namespace.keychainService,
            kSecAttrAccount as String: account(for: key),
        ]
    }

    private func account(for key: SecretKey) -> String {
        let server = key.serverID?.rawValue ?? "global"
        let identifier = key.identifier ?? "default"
        return [server, key.purpose.rawValue, identifier].joined(separator: ":")
    }
}

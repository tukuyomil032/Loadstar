import Foundation

public enum StorageNamespace: String, Codable, Sendable {
    case production
    case debug

    public var folderName: String {
        switch self {
        case .production:
            "LoadStar"
        case .debug:
            "LoadStar-Debug"
        }
    }

    public var keychainService: String {
        switch self {
        case .production:
            "com.tukuyomi032.loadstar"
        case .debug:
            "com.tukuyomi032.loadstar.debug"
        }
    }
}

public struct ManagedPath: Codable, Equatable, Hashable, Sendable {
    public let components: [String]

    public init(components: [String]) throws {
        guard !components.isEmpty else {
            throw DomainValidationError.invalidManagedPath(components)
        }

        for component in components {
            guard Self.isSafeComponent(component) else {
                throw DomainValidationError.invalidManagedPath(components)
            }
        }

        self.components = components
    }

    public init(_ component: String) throws {
        try self.init(components: [component])
    }

    public func appending(_ component: String) throws -> Self {
        try Self(components: components + [component])
    }

    public func appending(contentsOf additionalComponents: [String]) throws -> Self {
        try Self(components: components + additionalComponents)
    }

    public var relativePath: String {
        components.joined(separator: "/")
    }

    public var parent: Self? {
        guard components.count > 1 else {
            return nil
        }

        return try? Self(components: Array(components.dropLast()))
    }

    public static func serverDirectory(for id: ServerID) throws -> Self {
        try Self(components: ["servers", id.rawValue])
    }

    private static func isSafeComponent(_ component: String) -> Bool {
        guard !component.isEmpty, component != ".", component != ".." else {
            return false
        }

        guard !component.contains("/") && !component.contains("\\") else {
            return false
        }

        return component.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 0x20 && scalar.value != 0x7f
        }
    }
}

public struct FileMetadata: Codable, Equatable, Sendable {
    public let size: Int64
    public let modificationDate: Date?
    public let isDirectory: Bool
    public let isSymbolicLink: Bool

    public init(size: Int64, modificationDate: Date?, isDirectory: Bool, isSymbolicLink: Bool) {
        self.size = size
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
    }
}

public enum FileSystemError: Error, Codable, Equatable, Sendable {
    case notFound(ManagedPath)
    case permissionDenied(ManagedPath)
    case invalidPath(ManagedPath)
    case operationFailed(code: String, target: ManagedPath)
}

public protocol FileSystemClient: Sendable {
    func readData(at path: ManagedPath) async throws -> Data
    func writeData(_ data: Data, at path: ManagedPath) async throws
    func synchronize(at path: ManagedPath) async throws
    func createDirectory(at path: ManagedPath) async throws
    func replaceItem(at destination: ManagedPath, with source: ManagedPath) async throws
    func copyItem(at source: ManagedPath, to destination: ManagedPath) async throws
    func moveItem(at source: ManagedPath, to destination: ManagedPath) async throws
    func removeItem(at path: ManagedPath) async throws
    func exists(at path: ManagedPath) async throws -> Bool
    func metadata(at path: ManagedPath) async throws -> FileMetadata
    func listDirectory(at path: ManagedPath) async throws -> [ManagedPath]
}

import Foundation
import LoadStarDomain

public enum ArchiveEntryKind: String, Codable, Equatable, Sendable {
    case regularFile
    case directory
    case symbolicLink
    case hardLink
}

public struct ArchiveEntry: Codable, Equatable, Sendable {
    public let path: String
    public let kind: ArchiveEntryKind
    public let expectedChecksum: SHA256Digest?

    public init(path: String, kind: ArchiveEntryKind, expectedChecksum: SHA256Digest? = nil) {
        self.path = path
        self.kind = kind
        self.expectedChecksum = expectedChecksum
    }
}

public enum ArchiveEntryValidationError: Error, Equatable, Sendable {
    case absolutePath(String)
    case traversal(String)
    case linkEntry(String, ArchiveEntryKind)
    case duplicatePath(ManagedPath)
    case checksumMismatch(ManagedPath, expected: SHA256Digest, actual: SHA256Digest)
}

public struct ArchiveEntryValidator: Sendable {
    public init() {}

    public func validate(_ entries: [ArchiveEntry]) throws -> [ManagedPath] {
        var seen = Set<ManagedPath>()
        var paths: [ManagedPath] = []

        for entry in entries {
            let path = try validatedPath(for: entry.path)
            guard seen.insert(path).inserted else {
                throw ArchiveEntryValidationError.duplicatePath(path)
            }
            switch entry.kind {
            case .symbolicLink, .hardLink:
                throw ArchiveEntryValidationError.linkEntry(entry.path, entry.kind)
            case .regularFile, .directory:
                break
            }
            paths.append(path)
        }

        return paths
    }

    public func validateChecksum(
        expected: SHA256Digest,
        actual: SHA256Digest,
        path: ManagedPath
    ) throws {
        guard expected == actual else {
            throw ArchiveEntryValidationError.checksumMismatch(path, expected: expected, actual: actual)
        }
    }

    private func validatedPath(for rawPath: String) throws -> ManagedPath {
        guard !rawPath.isEmpty, !rawPath.hasPrefix("/"), !rawPath.hasPrefix("\\") else {
            throw ArchiveEntryValidationError.absolutePath(rawPath)
        }
        guard !rawPath.contains("\\") else {
            throw ArchiveEntryValidationError.traversal(rawPath)
        }

        let components = rawPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains(".."), !components.contains(".") else {
            throw ArchiveEntryValidationError.traversal(rawPath)
        }
        do {
            return try ManagedPath(components: components)
        } catch {
            throw ArchiveEntryValidationError.traversal(rawPath)
        }
    }
}

import Foundation
import LoadStarDomain

public struct ManagedRoot: Sendable {
    public let namespace: StorageNamespace
    public let rootURL: URL

    public init(applicationSupportURL: URL, namespace: StorageNamespace) {
        self.namespace = namespace
        self.rootURL =
            applicationSupportURL
            .appendingPathComponent(namespace.folderName, isDirectory: true)
            .standardizedFileURL
    }

    public static func applicationSupport(namespace: StorageNamespace) throws -> Self {
        guard
            let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw ManagedRootError.applicationSupportUnavailable
        }
        return Self(applicationSupportURL: applicationSupportURL, namespace: namespace)
    }

    @discardableResult
    public func ensureExists() throws -> URL {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let validator = ManagedPathValidator(rootURL: rootURL)
        let canonicalRoot = try validator.canonicalRoot()
        guard canonicalRoot.path == rootURL.path else {
            throw ManagedPathValidationError.rootIsSymbolicLink
        }
        return canonicalRoot
    }

    public func resolve(_ path: ManagedPath) throws -> URL {
        try ManagedPathValidator(rootURL: rootURL).resolve(path)
    }

    public func fileSystemClient() throws -> LocalFileSystemClient {
        _ = try ensureExists()
        return LocalFileSystemClient(root: self)
    }
}

public enum ManagedRootError: Error, Equatable, Sendable {
    case applicationSupportUnavailable
}

public final class LocalFileSystemClient: FileSystemClient, @unchecked Sendable {
    private let root: ManagedRoot
    private let fileManager: FileManager

    public init(root: ManagedRoot, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func readData(at path: ManagedPath) async throws -> Data {
        do {
            return try Data(contentsOf: try url(for: path), options: [.mappedIfSafe])
        } catch {
            throw map(error, for: path)
        }
    }

    public func writeData(_ data: Data, at path: ManagedPath) async throws {
        do {
            let destination = try url(for: path)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: [.atomic])
        } catch {
            throw map(error, for: path)
        }
    }

    public func synchronize(at path: ManagedPath) async throws {
        do {
            let handle = try FileHandle(forWritingTo: try url(for: path))
            try handle.synchronize()
            try handle.close()
        } catch {
            throw map(error, for: path)
        }
    }

    public func createDirectory(at path: ManagedPath) async throws {
        do {
            let directory = try url(for: path)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            _ = try ManagedPathValidator(rootURL: root.rootURL).resolve(path)
        } catch {
            throw map(error, for: path)
        }
    }

    public func replaceItem(at destination: ManagedPath, with source: ManagedPath) async throws {
        do {
            let destinationURL = try url(for: destination)
            let sourceURL = try url(for: source)
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: sourceURL)
            } else {
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            throw map(error, for: destination)
        }
    }

    public func copyItem(at source: ManagedPath, to destination: ManagedPath) async throws {
        do {
            try fileManager.copyItem(at: try url(for: source), to: try url(for: destination))
        } catch {
            throw map(error, for: destination)
        }
    }

    public func moveItem(at source: ManagedPath, to destination: ManagedPath) async throws {
        do {
            try fileManager.moveItem(at: try url(for: source), to: try url(for: destination))
        } catch {
            throw map(error, for: destination)
        }
    }

    public func removeItem(at path: ManagedPath) async throws {
        do {
            try fileManager.removeItem(at: try url(for: path))
        } catch {
            throw map(error, for: path)
        }
    }

    public func exists(at path: ManagedPath) async throws -> Bool {
        let candidate = try url(for: path)
        return fileManager.fileExists(atPath: candidate.path)
    }

    public func metadata(at path: ManagedPath) async throws -> FileMetadata {
        do {
            let candidate = try url(for: path)
            let values = try candidate.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
            guard let isDirectory = values.isDirectory else {
                throw FileSystemError.notFound(path)
            }
            return FileMetadata(
                size: Int64(values.fileSize ?? 0),
                modificationDate: values.contentModificationDate,
                isDirectory: isDirectory,
                isSymbolicLink: values.isSymbolicLink ?? false
            )
        } catch let error as FileSystemError {
            throw error
        } catch {
            throw map(error, for: path)
        }
    }

    public func listDirectory(at path: ManagedPath) async throws -> [ManagedPath] {
        do {
            let directory = try url(for: path)
            let children = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            let canonicalRoot = try ManagedPathValidator(rootURL: root.rootURL).canonicalRoot()
            return try children.map { child in
                let canonicalChild = child.resolvingSymlinksInPath().standardizedFileURL
                let rootComponents = canonicalRoot.pathComponents
                let childComponents = canonicalChild.pathComponents
                guard childComponents.starts(with: rootComponents) else {
                    throw ManagedPathValidationError.symbolicLinkEscape(path)
                }
                let childPath = try ManagedPath(components: Array(childComponents.dropFirst(rootComponents.count)))
                _ = try url(for: childPath)
                return childPath
            }
        } catch {
            throw map(error, for: path)
        }
    }

    private func url(for path: ManagedPath) throws -> URL {
        try root.resolve(path)
    }

    private func map(_ error: Error, for path: ManagedPath) -> FileSystemError {
        if let error = error as? FileSystemError {
            return error
        }
        if let error = error as? ManagedPathValidationError {
            return .operationFailed(code: "path.validation.\(String(describing: error))", target: path)
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
            nsError.code == NSFileNoSuchFileError || nsError.code == NSFileReadNoSuchFileError
        {
            return .notFound(path)
        }
        if nsError.domain == NSCocoaErrorDomain,
            nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileReadNoPermissionError
        {
            return .permissionDenied(path)
        }
        return .operationFailed(code: "filesystem.\(nsError.domain).\(nsError.code)", target: path)
    }
}

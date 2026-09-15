import Foundation
import LoadStarDomain

public enum ManagedPathValidationError: Error, Equatable, Sendable {
    case rootIsSymbolicLink
    case pathEscapesRoot(ManagedPath)
    case symbolicLinkEscape(ManagedPath)
}

public struct ManagedPathValidator: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    public func resolve(_ path: ManagedPath) throws -> URL {
        let root = try canonicalRoot()

        var current = root
        for component in path.components {
            current = current.appendingPathComponent(component, isDirectory: false)
            if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: current.path) {
                let target: URL
                if destination.hasPrefix("/") {
                    target = URL(fileURLWithPath: destination)
                } else {
                    target = current.deletingLastPathComponent().appendingPathComponent(destination)
                }
                let resolvedTarget = target.resolvingSymlinksInPath().standardizedFileURL
                guard isWithinRoot(resolvedTarget.path, rootPath: root.path) else {
                    throw ManagedPathValidationError.symbolicLinkEscape(path)
                }
            }
        }

        let candidate = path.components.reduce(root) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard isWithinRoot(resolved.path, rootPath: root.path) else {
            throw ManagedPathValidationError.symbolicLinkEscape(path)
        }
        return candidate.standardizedFileURL
    }

    public func canonicalRoot() throws -> URL {
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: rootURL.path)) != nil {
            throw ManagedPathValidationError.rootIsSymbolicLink
        }
        let root = rootURL.resolvingSymlinksInPath().standardizedFileURL
        return root
    }

    private func isWithinRoot(_ candidatePath: String, rootPath: String) -> Bool {
        candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}

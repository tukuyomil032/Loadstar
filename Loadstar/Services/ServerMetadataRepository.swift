import Foundation
import LoadStarDomain
import LoadStarPersistence
import LoadStarPlatform

public enum ServerMetadataRepositoryError: Error, Equatable, Sendable {
    case missing(ServerID)
    case repairRequired(ServerID, PersistenceIssue)
    case failed(ServerID, PersistenceIssue)
}

public protocol ServerMetadataRepository: Sendable {
    func load(serverID: ServerID) async throws -> ServerMetadata
    func save(_ metadata: ServerMetadata, serverID: ServerID) async throws
}

public struct ManagedServerMetadataRepository: ServerMetadataRepository {
    private let store: DocumentStore

    public init(
        fileSystem: any FileSystemClient,
        clock: any Clock = SystemClock(),
        migrations: MigrationCoordinator = ServerMetadataMigrations.coordinator()
    ) {
        self.store = DocumentStore(fileSystem: fileSystem, clock: clock, migrations: migrations)
    }

    public func load(serverID: ServerID) async throws -> ServerMetadata {
        let state = await store.load(
            ServerMetadata.self,
            documentType: .serverMetadata,
            at: try Self.metadataPath(for: serverID)
        )
        switch state {
        case .loaded(let metadata), .migrated(let metadata, _):
            return metadata
        case .missing:
            throw ServerMetadataRepositoryError.missing(serverID)
        case .repairRequired(let issue), .permissionDenied(let issue), .rolledBack(let issue, _):
            throw ServerMetadataRepositoryError.repairRequired(serverID, issue)
        case .failed(let issue):
            throw ServerMetadataRepositoryError.failed(serverID, issue)
        case .initialized, .unsupportedReadOnly:
            throw ServerMetadataRepositoryError.failed(
                serverID,
                PersistenceIssue(
                    code: "server.metadata.unsupportedState",
                    stage: .validation,
                    documentType: .serverMetadata,
                    target: try Self.metadataPath(for: serverID),
                    userVisibleOutcome: "The server metadata is not ready for lifecycle operations.",
                    retryability: .userActionRequired,
                    recoveryAction: .manualRepair
                ))
        }
    }

    public func save(_ metadata: ServerMetadata, serverID: ServerID) async throws {
        guard metadata.identity.id == serverID else {
            throw ServerMetadataRepositoryError.failed(
                serverID,
                PersistenceIssue(
                    code: "server.metadata.idMismatch",
                    stage: .validation,
                    documentType: .serverMetadata,
                    target: try Self.metadataPath(for: serverID),
                    userVisibleOutcome: "The metadata identity does not match the requested server.",
                    retryability: .terminal,
                    recoveryAction: .manualRepair
                ))
        }
        let document = try LoadStarDocument(
            documentType: .serverMetadata,
            revision: ServerMetadata.currentSchemaRevision,
            payload: metadata
        )
        let state = await store.save(document, at: try Self.metadataPath(for: serverID))
        if case .loaded = state { return }
        if case .failed(let issue) = state { throw ServerMetadataRepositoryError.failed(serverID, issue) }
        throw ServerMetadataRepositoryError.failed(
            serverID,
            PersistenceIssue(
                code: "server.metadata.saveFailed",
                stage: .write,
                documentType: .serverMetadata,
                target: try Self.metadataPath(for: serverID),
                userVisibleOutcome: "The server metadata could not be saved.",
                retryability: .retryable,
                recoveryAction: .retry
            ))
    }

    public static func metadataPath(for serverID: ServerID) throws -> ManagedPath {
        try ManagedPath(components: ["servers", serverID.rawValue, "metadata.json"])
    }

    public static func serverDirectory(for serverID: ServerID) throws -> ManagedPath {
        try ManagedPath.serverDirectory(for: serverID)
    }
}

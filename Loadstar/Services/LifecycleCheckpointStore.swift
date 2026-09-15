import Foundation
import LoadStarDomain
import LoadStarPersistence
import LoadStarPlatform

public protocol LifecycleCheckpointStore: Sendable {
    func save(_ checkpoint: OperationCheckpoint) async throws
}

public actor InMemoryLifecycleCheckpointStore: LifecycleCheckpointStore {
    public private(set) var checkpoints: [OperationID: OperationCheckpoint] = [:]

    public init() {}

    public func save(_ checkpoint: OperationCheckpoint) async throws {
        checkpoints[checkpoint.id] = checkpoint
    }
}

public struct ManagedLifecycleCheckpointStore: LifecycleCheckpointStore {
    private let store: DocumentStore

    public init(fileSystem: any FileSystemClient, clock: any Clock = SystemClock()) {
        self.store = DocumentStore(fileSystem: fileSystem, clock: clock)
    }

    public func save(_ checkpoint: OperationCheckpoint) async throws {
        let document = try LoadStarDocument(
            documentType: .operation,
            revision: OperationCheckpoint.currentSchemaRevision,
            payload: checkpoint
        )
        let path = try ManagedPath(components: ["operations", "\(checkpoint.id.rawValue).json"])
        let state = await store.save(document, at: path)
        if case .loaded = state { return }
        throw LifecycleCheckpointError.saveFailed
    }
}

public enum LifecycleCheckpointError: Error, Equatable, Sendable {
    case saveFailed
}

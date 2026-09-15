import Foundation

public enum OperationStage: String, Codable, Equatable, Sendable {
    case preparing
    case staging
    case validating
    case committing
    case rollingBack
    case completed
    case failed
    case cancelled
}

public enum OperationStatus: String, Codable, Equatable, Sendable {
    case pending
    case running
    case succeeded
    case partiallySucceeded
    case failed
    case cancelled
    case needsRecovery
}

public enum LifecycleCheckpointStage: String, Codable, Equatable, Sendable {
    case launch
    case probing
    case stopping
    case forceTerminationPending
    case crash
    case cleanup
}

public struct LifecycleCheckpointPayload: Codable, Equatable, Sendable {
    public let stage: LifecycleCheckpointStage
    public let serverID: ServerID
    public let sessionID: ProcessSessionID?

    public init(stage: LifecycleCheckpointStage, serverID: ServerID, sessionID: ProcessSessionID? = nil) {
        self.stage = stage
        self.serverID = serverID
        self.sessionID = sessionID
    }
}

public struct OperationCheckpoint: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    public static let documentType = DocumentType.operation
    public static let currentSchemaRevision = 1

    public let id: OperationID
    public let serverID: ServerID?
    public var stage: OperationStage
    public var status: OperationStatus
    public var progress: Double
    public var checkpointPayload: JSONValue?
    public var issue: PersistenceIssue?
    public var recoveryAction: RecoveryAction

    public init(
        id: OperationID,
        serverID: ServerID?,
        stage: OperationStage,
        status: OperationStatus,
        progress: Double,
        checkpointPayload: JSONValue? = nil,
        issue: PersistenceIssue? = nil,
        recoveryAction: RecoveryAction = .none
    ) throws {
        guard (0...1).contains(progress) else {
            throw DomainValidationError.invalidProgress(progress)
        }

        self.id = id
        self.serverID = serverID
        self.stage = stage
        self.status = status
        self.progress = progress
        self.checkpointPayload = checkpointPayload
        self.issue = issue
        self.recoveryAction = recoveryAction
    }

    public func validate() throws {
        guard (0...1).contains(progress) else {
            throw DomainValidationError.invalidProgress(progress)
        }
    }
}

import Foundation

public enum DomainValidationError: Error, Equatable, Sendable {
    case invalidServerID(String)
    case invalidOperationID(String)
    case invalidSchemaRevision(Int)
    case nonFiniteJSONNumber
    case invalidJSONValue
    case invalidManagedPath([String])
    case invalidDisplayName
    case invalidMemoryMiB(Int)
    case invalidJarFileName(String)
    case invalidChecksum(String)
    case invalidSchedule
    case invalidPolicy
    case duplicateServerID(ServerID)
    case mismatchedServerID
    case invalidProgress(Double)
}

public enum FailureStage: String, Codable, Sendable {
    case read
    case encode
    case decode
    case validation
    case backup
    case migration
    case quarantine
    case write
    case synchronize
    case replace
    case cleanup
    case pathValidation
    case archiveValidation
    case keychain
}

public enum Retryability: String, Codable, Sendable {
    case retryable
    case userActionRequired
    case terminal
}

public enum RecoveryAction: String, Codable, Sendable {
    case retry
    case chooseDifferentPath
    case restoreLastKnownGood
    case inspectQuarantine
    case updateApplication
    case reauthorize
    case manualRepair
    case none
}

public struct PersistenceIssue: Codable, Equatable, Sendable {
    public let code: String
    public let stage: FailureStage
    public let documentType: DocumentType?
    public let target: ManagedPath?
    public let userVisibleOutcome: String
    public let retryability: Retryability
    public let retainedData: String?
    public let cleanupResult: String?
    public let recoveryAction: RecoveryAction
    public let redactedDetail: String?

    public init(
        code: String,
        stage: FailureStage,
        documentType: DocumentType? = nil,
        target: ManagedPath? = nil,
        userVisibleOutcome: String,
        retryability: Retryability,
        retainedData: String? = nil,
        cleanupResult: String? = nil,
        recoveryAction: RecoveryAction,
        redactedDetail: String? = nil
    ) {
        self.code = code
        self.stage = stage
        self.documentType = documentType
        self.target = target
        self.userVisibleOutcome = userVisibleOutcome
        self.retryability = retryability
        self.retainedData = retainedData
        self.cleanupResult = cleanupResult
        self.recoveryAction = recoveryAction
        self.redactedDetail = redactedDetail
    }
}

public struct OperationID: Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) throws {
        guard let uuid = UUID(uuidString: rawValue) else {
            throw DomainValidationError.invalidOperationID(rawValue)
        }

        self.rawValue = uuid.uuidString.lowercased()
    }

    public static func new() -> Self {
        Self(uncheckedRawValue: UUID().uuidString)
    }

    private init(uncheckedRawValue: String) {
        self.rawValue = uncheckedRawValue.lowercased()
    }
}

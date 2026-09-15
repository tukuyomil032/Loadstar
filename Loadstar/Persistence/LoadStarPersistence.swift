import Foundation
import LoadStarDomain

public enum LoadStarPersistence: Sendable {
    public static let managedRootFolderName = LoadStarDomain.productName
}

public struct MigrationBackup: Codable, Equatable, Sendable {
    public let id: OperationID
    public let documentType: DocumentType
    public let fromRevision: Int
    public let path: ManagedPath
    public let createdAt: Date

    public init(
        id: OperationID,
        documentType: DocumentType,
        fromRevision: Int,
        path: ManagedPath,
        createdAt: Date
    ) {
        self.id = id
        self.documentType = documentType
        self.fromRevision = fromRevision
        self.path = path
        self.createdAt = createdAt
    }
}

public struct UnsupportedDocument: Codable, Equatable, Sendable {
    public let documentType: DocumentType
    public let revision: Int
    public let supportedRevision: Int

    public init(documentType: DocumentType, revision: Int, supportedRevision: Int) {
        self.documentType = documentType
        self.revision = revision
        self.supportedRevision = supportedRevision
    }
}

public struct QuarantineRecord: Codable, Equatable, Sendable {
    public let id: OperationID
    public let documentType: DocumentType?
    public let detectedRevision: Int?
    public let path: ManagedPath
    public let issueCode: String
    public let detectedAt: Date

    public init(
        id: OperationID,
        documentType: DocumentType?,
        detectedRevision: Int?,
        path: ManagedPath,
        issueCode: String,
        detectedAt: Date
    ) {
        self.id = id
        self.documentType = documentType
        self.detectedRevision = detectedRevision
        self.path = path
        self.issueCode = issueCode
        self.detectedAt = detectedAt
    }
}

public struct RestoreConfirmation: Codable, Equatable, Sendable {
    public let candidateID: OperationID

    public init(candidateID: OperationID) {
        self.candidateID = candidateID
    }
}

public enum PersistenceState<Value: Sendable>: Sendable {
    case missing
    case initialized(Value)
    case loaded(Value)
    case migrated(Value, backup: MigrationBackup)
    case unsupportedReadOnly(UnsupportedDocument)
    case repairRequired(PersistenceIssue)
    case permissionDenied(PersistenceIssue)
    case rolledBack(PersistenceIssue, backup: MigrationBackup?)
    case failed(PersistenceIssue)
}

public struct PersistenceFailure: Error, Equatable, Sendable {
    public let issue: PersistenceIssue

    public init(issue: PersistenceIssue) {
        self.issue = issue
    }
}

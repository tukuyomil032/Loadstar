import Foundation
import LoadStarDomain

// The actor intentionally owns the complete persistence state machine so all recovery branches are serialized.
// swiftlint:disable type_body_length
public actor DocumentStore {
    private let fileSystem: any FileSystemClient
    private let clock: any Clock
    private let codec: DocumentCodec
    private let migrations: MigrationCoordinator
    private let writer: AtomicDocumentWriter
    private let quarantineStore: QuarantineStore
    private var diagnostics: [PersistenceIssue] = []
    private var pendingMigrationBackups: [ManagedPath: MigrationBackup] = [:]

    public init(
        fileSystem: any FileSystemClient,
        clock: any Clock = SystemClock(),
        codec: DocumentCodec = DocumentCodec(),
        migrations: MigrationCoordinator = MigrationCoordinator()
    ) {
        self.fileSystem = fileSystem
        self.clock = clock
        self.codec = codec
        self.migrations = migrations
        self.writer = AtomicDocumentWriter(fileSystem: fileSystem, codec: codec)
        self.quarantineStore = QuarantineStore(fileSystem: fileSystem, clock: clock)
    }

    public func recordedDiagnostics() -> [PersistenceIssue] {
        diagnostics
    }

    public func load<Payload: LoadStarDocumentPayload>(
        _ type: Payload.Type,
        documentType: DocumentType,
        at path: ManagedPath
    ) async -> PersistenceState<Payload> {
        do {
            guard try await fileSystem.exists(at: path) else {
                return .missing
            }

            let data = try await fileSystem.readData(at: path)
            let header = try codec.decodeHeader(from: data)
            guard header.documentType == documentType else {
                return await quarantineCorruptDocument(
                    data: data,
                    path: path,
                    header: header,
                    documentType: documentType,
                    code: "document.typeMismatch"
                )
            }

            let currentRevision = Payload.currentSchemaRevision
            if header.revision > currentRevision {
                return .unsupportedReadOnly(
                    UnsupportedDocument(
                        documentType: documentType,
                        revision: header.revision,
                        supportedRevision: currentRevision
                    )
                )
            }

            if header.revision < currentRevision {
                return await migrate(
                    type,
                    documentType: documentType,
                    path: path,
                    data: data,
                    header: header
                )
            }

            do {
                let document = try codec.decode(type, from: data, expectedDocumentType: documentType)
                try document.payload.validate()
                return .loaded(document.payload)
            } catch {
                return await quarantineCorruptDocument(
                    data: data,
                    path: path,
                    header: header,
                    documentType: documentType,
                    code: "document.invalid"
                )
            }
        } catch let error as FileSystemError {
            return state(for: error, documentType: documentType, target: path)
        } catch {
            return await quarantineCorruptDocument(
                data: nil,
                path: path,
                header: nil,
                documentType: documentType,
                code: "document.corrupt"
            )
        }
    }

    public func save<Payload: LoadStarDocumentPayload>(
        _ document: LoadStarDocument<Payload>,
        at path: ManagedPath
    ) async -> PersistenceState<Payload> {
        do {
            guard document.documentType == Payload.documentType else {
                return .failed(
                    issue(
                        code: "document.payloadTypeMismatch",
                        stage: .validation,
                        documentType: document.documentType,
                        target: path,
                        outcome: "The payload type does not match the document type.",
                        retryability: .terminal,
                        recoveryAction: .manualRepair
                    ))
            }

            try document.payload.validate()
            let data = try codec.encode(document)
            let state = await atomicWrite(data: data, document: document, at: path)
            if case .loaded = state {
                await cleanupMigrationBackup(for: path, documentType: document.documentType)
            }
            return state
        } catch {
            return .failed(
                issue(
                    code: "document.encodeFailed",
                    stage: .encode,
                    documentType: document.documentType,
                    target: path,
                    outcome: "The document could not be encoded.",
                    retryability: .terminal,
                    recoveryAction: .manualRepair,
                    detail: String(describing: error)
                ))
        }
    }

    public func restoreLastKnownGood<Payload: LoadStarDocumentPayload>(
        _ type: Payload.Type,
        documentType: DocumentType,
        candidate: MigrationBackup,
        confirmation: RestoreConfirmation,
        at destination: ManagedPath
    ) async -> PersistenceState<Payload> {
        guard confirmation.candidateID == candidate.id else {
            return .failed(
                issue(
                    code: "recovery.confirmationMismatch",
                    stage: .validation,
                    documentType: documentType,
                    target: destination,
                    outcome: "The recovery confirmation does not match the selected candidate.",
                    retryability: .userActionRequired,
                    recoveryAction: .restoreLastKnownGood
                ))
        }

        do {
            let data = try await fileSystem.readData(at: candidate.path)
            let document = try codec.decode(type, from: data, expectedDocumentType: documentType)
            try document.payload.validate()
            return await atomicWrite(data: try codec.encode(document), document: document, at: destination)
        } catch let error as FileSystemError {
            return state(for: error, documentType: documentType, target: destination)
        } catch {
            return .repairRequired(
                issue(
                    code: "recovery.candidateInvalid",
                    stage: .validation,
                    documentType: documentType,
                    target: destination,
                    outcome: "The selected recovery candidate requires manual repair.",
                    retryability: .userActionRequired,
                    recoveryAction: .inspectQuarantine,
                    detail: String(describing: error)
                ))
        }
    }

    private func migrate<Payload: LoadStarDocumentPayload>(
        _ type: Payload.Type,
        documentType: DocumentType,
        path: ManagedPath,
        data: Data,
        header: DocumentHeader
    ) async -> PersistenceState<Payload> {
        let backup: MigrationBackup
        switch await prepareMigrationBackup(documentType: documentType, path: path, header: header) {
        case .success(let preparedBackup):
            backup = preparedBackup
        case .failure(let failure):
            return .failed(failure)
        }

        let migratedRaw: JSONValue
        do {
            let raw = try codec.decodeRaw(data)
            migratedRaw = try migrations.migrate(
                raw,
                documentType: documentType,
                fromRevision: header.revision,
                toRevision: Payload.currentSchemaRevision
            )
        } catch {
            return .rolledBack(
                issue(
                    code: "migration.transformFailed",
                    stage: .migration,
                    documentType: documentType,
                    target: path,
                    outcome: "Migration failed before replacing the original document.",
                    retryability: .userActionRequired,
                    retainedData: "Original document and migration backup retained.",
                    recoveryAction: .restoreLastKnownGood,
                    detail: String(describing: error)
                ),
                backup: backup
            )
        }

        let document: LoadStarDocument<Payload>
        do {
            let migratedData = try codec.encodeRaw(migratedRaw)
            document = try codec.decode(type, from: migratedData, expectedDocumentType: documentType)
            try document.payload.validate()
        } catch {
            return .rolledBack(
                issue(
                    code: "migration.validationFailed",
                    stage: .validation,
                    documentType: documentType,
                    target: path,
                    outcome: "Migration produced a document that failed schema or typed validation.",
                    retryability: .userActionRequired,
                    retainedData: "Original document and migration backup retained.",
                    recoveryAction: .restoreLastKnownGood,
                    detail: String(describing: error)
                ),
                backup: backup
            )
        }

        let encodedDocument: Data
        do {
            encodedDocument = try codec.encode(document)
        } catch {
            return .rolledBack(
                issue(
                    code: "migration.encodeFailed",
                    stage: .encode,
                    documentType: documentType,
                    target: path,
                    outcome: "The migrated document could not be encoded.",
                    retryability: .userActionRequired,
                    retainedData: "Original document and migration backup retained.",
                    recoveryAction: .restoreLastKnownGood,
                    detail: String(describing: error)
                ),
                backup: backup
            )
        }

        let result = await atomicWrite(data: encodedDocument, document: document, at: path)
        switch result {
        case .loaded:
            pendingMigrationBackups[path] = backup
            return .migrated(document.payload, backup: backup)
        case .failed(let failure):
            return .rolledBack(failure, backup: backup)
        case .permissionDenied(let failure):
            return .rolledBack(failure, backup: backup)
        case .repairRequired(let failure):
            return .rolledBack(failure, backup: backup)
        case .rolledBack(let failure, _):
            return .rolledBack(failure, backup: backup)
        default:
            return .rolledBack(
                issue(
                    code: "migration.commitFailed",
                    stage: .replace,
                    documentType: documentType,
                    target: path,
                    outcome: "Migration did not commit the converted document.",
                    retryability: .retryable,
                    retainedData: "Original document and migration backup retained.",
                    recoveryAction: .retry
                ),
                backup: backup
            )
        }
    }

    private func prepareMigrationBackup(
        documentType: DocumentType,
        path: ManagedPath,
        header: DocumentHeader
    ) async -> MigrationBackupPreparation {
        let backupID = OperationID.new()
        do {
            let backupPath = try ManagedPath(components: [
                "quarantine",
                "migration-backups",
                "\(documentType.rawValue)-\(backupID.rawValue).json",
            ])
            if let parent = backupPath.parent {
                try await fileSystem.createDirectory(at: parent)
            }
            try await fileSystem.copyItem(at: path, to: backupPath)
            return .success(
                MigrationBackup(
                    id: backupID,
                    documentType: documentType,
                    fromRevision: header.revision,
                    path: backupPath,
                    createdAt: clock.now()
                ))
        } catch {
            return .failure(
                issue(
                    code: "migration.backupFailed",
                    stage: .backup,
                    documentType: documentType,
                    target: path,
                    outcome: "The original document was retained, but migration backup could not be created.",
                    retryability: .retryable,
                    retainedData: "Original document retained.",
                    recoveryAction: .retry,
                    detail: String(describing: error)
                ))
        }
    }

    private func cleanupMigrationBackup(for path: ManagedPath, documentType: DocumentType) async {
        guard let backup = pendingMigrationBackups[path] else {
            return
        }

        do {
            guard try await fileSystem.exists(at: backup.path) else {
                pendingMigrationBackups.removeValue(forKey: path)
                return
            }
            try await fileSystem.removeItem(at: backup.path)
            pendingMigrationBackups.removeValue(forKey: path)
        } catch {
            diagnostics.append(
                issue(
                    code: "migration.backupCleanupPending",
                    stage: .cleanup,
                    documentType: documentType,
                    target: path,
                    outcome:
                        "The document was saved, but its previous migration backup remains available for recovery.",
                    retryability: .retryable,
                    retainedData: "Saved document and migration backup retained.",
                    recoveryAction: .retry,
                    detail: String(describing: error)
                ))
        }
    }

    private func atomicWrite<Payload: LoadStarDocumentPayload>(
        data: Data,
        document: LoadStarDocument<Payload>,
        at path: ManagedPath
    ) async -> PersistenceState<Payload> {
        do {
            let result = try await writer.write(data: data, document: document, at: path)
            if let cleanupResult = result.cleanupResult {
                diagnostics.append(
                    issue(
                        code: "document.temporaryCleanupPending",
                        stage: .cleanup,
                        documentType: document.documentType,
                        target: path,
                        outcome: "The document was saved, but a temporary artifact requires cleanup.",
                        retryability: .retryable,
                        retainedData: "Saved document retained.",
                        recoveryAction: .retry,
                        detail: cleanupResult
                    ))
            }
            return .loaded(result.value)
        } catch let failure as AtomicWriteFailure {
            return .failed(
                issue(
                    code: "document.atomicWriteFailed",
                    stage: failure.stage,
                    documentType: document.documentType,
                    target: path,
                    outcome: "The existing document was preserved because the atomic write failed.",
                    retryability: .retryable,
                    retainedData: "Existing document retained.",
                    cleanupResult: failure.cleanupResult,
                    recoveryAction: .retry,
                    detail: failure.detail
                ))
        } catch {
            return .failed(
                issue(
                    code: "document.atomicValidationFailed",
                    stage: .validation,
                    documentType: document.documentType,
                    target: path,
                    outcome: "The existing document was preserved because read-back validation failed.",
                    retryability: .terminal,
                    retainedData: "Existing document retained.",
                    recoveryAction: .manualRepair,
                    detail: String(describing: error)
                ))
        }
    }

    private func quarantineCorruptDocument<Payload: Sendable>(
        data _: Data?,
        path: ManagedPath,
        header: DocumentHeader?,
        documentType: DocumentType,
        code: String
    ) async -> PersistenceState<Payload> {
        do {
            let record = try await quarantineStore.quarantine(
                path: path,
                header: header,
                documentType: documentType,
                issueCode: code
            )
            return .repairRequired(
                issue(
                    code: code,
                    stage: .quarantine,
                    documentType: documentType,
                    target: path,
                    outcome: "The document was quarantined and requires repair.",
                    retryability: .userActionRequired,
                    retainedData: "Quarantined at \(record.path.relativePath).",
                    recoveryAction: .inspectQuarantine
                ))
        } catch let error as FileSystemError {
            return .repairRequired(
                issue(
                    code: "document.quarantineFailed",
                    stage: .quarantine,
                    documentType: documentType,
                    target: path,
                    outcome: "The document is invalid and could not be quarantined.",
                    retryability: .userActionRequired,
                    retainedData: "Original document retained.",
                    recoveryAction: .manualRepair,
                    detail: String(describing: error)
                ))
        } catch {
            return .repairRequired(
                issue(
                    code: "document.quarantineFailed",
                    stage: .quarantine,
                    documentType: documentType,
                    target: path,
                    outcome: "The document is invalid and could not be quarantined.",
                    retryability: .userActionRequired,
                    retainedData: "Original document retained.",
                    recoveryAction: .manualRepair,
                    detail: String(describing: error)
                ))
        }
    }

    private func state<Value: Sendable>(
        for error: FileSystemError,
        documentType: DocumentType,
        target: ManagedPath
    ) -> PersistenceState<Value> {
        switch error {
        case .permissionDenied:
            .permissionDenied(
                issue(
                    code: "document.permissionDenied",
                    stage: .read,
                    documentType: documentType,
                    target: target,
                    outcome: "The document could not be accessed because permission was denied.",
                    retryability: .userActionRequired,
                    recoveryAction: .reauthorize,
                    detail: String(describing: error)
                ))
        default:
            .failed(
                issue(
                    code: "document.readFailed",
                    stage: .read,
                    documentType: documentType,
                    target: target,
                    outcome: "The document could not be read.",
                    retryability: .retryable,
                    recoveryAction: .retry,
                    detail: String(describing: error)
                ))
        }
    }

    private func issue(
        code: String,
        stage: FailureStage,
        documentType: DocumentType? = nil,
        target: ManagedPath? = nil,
        outcome: String,
        retryability: Retryability,
        retainedData: String? = nil,
        cleanupResult: String? = nil,
        recoveryAction: RecoveryAction,
        detail: String? = nil
    ) -> PersistenceIssue {
        PersistenceIssue(
            code: code,
            stage: stage,
            documentType: documentType,
            target: target,
            userVisibleOutcome: outcome,
            retryability: retryability,
            retainedData: retainedData,
            cleanupResult: cleanupResult,
            recoveryAction: recoveryAction,
            redactedDetail: detail
        )
    }

}
// swiftlint:enable type_body_length

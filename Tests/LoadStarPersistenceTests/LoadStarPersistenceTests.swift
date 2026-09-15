import Foundation
import LoadStarDomain
import XCTest

@testable import LoadStarPersistence

// The test class intentionally keeps the persistence state-machine scenarios together.
// swiftlint:disable type_body_length
final class LoadStarPersistenceTests: XCTestCase {
    func testManagedRootFolderNameIsStable() {
        XCTAssertEqual(LoadStarPersistence.managedRootFolderName, "LoadStar")
    }

    func testFixtureBundleContainsDeterministicSchemaCases() throws {
        let codec = DocumentCodec()
        let indexData = try FixtureLoader.data(at: "Persistence/server-index/valid.json")
        let index = try codec.decode(ServerIndex.self, from: indexData, expectedDocumentType: .serverIndex)
        XCTAssertEqual(index.schemaVersion.revision, 1)
        XCTAssertEqual(
            index.payload.entries.map(\.id.rawValue),
            [
                "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            ])

        let corruptData = try FixtureLoader.data(at: "Persistence/corrupt/malformed.json")
        XCTAssertThrowsError(try codec.decodeRaw(corruptData))
    }

    func testCodecFlattensPayloadAndRetainsUnknownFields() throws {
        let payload = CodecPayload(name: "alpha", count: 3)
        let document = try LoadStarDocument(
            documentType: .serverMetadata,
            revision: CodecPayload.currentSchemaRevision,
            payload: payload,
            unknownFields: ["future": .object(["enabled": .boolean(true)])]
        )
        let codec = DocumentCodec()

        let encoded = try codec.encode(document)
        let raw = try codec.decodeRaw(encoded)

        guard case .object(let fields) = raw else {
            return XCTFail("The wire document must be an object.")
        }

        XCTAssertEqual(fields["documentType"], .string("server-metadata"))
        XCTAssertEqual(fields["schemaVersion"], .integer(1))
        XCTAssertEqual(fields["name"], .string("alpha"))
        XCTAssertNil(fields["payload"])
        XCTAssertEqual(fields["future"], .object(["enabled": .boolean(true)]))

        let decoded = try codec.decode(
            CodecPayload.self,
            from: encoded,
            expectedDocumentType: .serverMetadata
        )
        XCTAssertEqual(decoded.payload, payload)
        XCTAssertEqual(decoded.unknownFields["future"], .object(["enabled": .boolean(true)]))
    }

    func testCodecRetainsUnknownNestedObjectFields() throws {
        let raw: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "settings": .object([
                "name": .string("alpha"),
                "futureSetting": .object(["mode": .string("safe")]),
            ]),
        ])
        let codec = DocumentCodec()
        let data = try codec.encodeRaw(raw)

        let decoded = try codec.decode(
            NestedCodecPayload.self,
            from: data,
            expectedDocumentType: .serverMetadata
        )

        XCTAssertEqual(
            decoded.unknownFields["settings"],
            .object(["futureSetting": .object(["mode": .string("safe")])])
        )
        XCTAssertEqual(try codec.encode(decoded), data)
    }

    func testStoreSavesAndLoadsDeterministicDocument() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "alpha", "metadata.json"])
        let document = try makeDocument(name: "alpha", count: 1)

        let saveState = await store.save(document, at: path)
        guard case .loaded(let savedPayload) = saveState else {
            return XCTFail("Expected a loaded state after save, got \(String(describing: saveState)).")
        }
        XCTAssertEqual(savedPayload, document.payload)

        let loadState = await store.load(CodecPayload.self, documentType: .serverMetadata, at: path)
        guard case .loaded(let loadedPayload) = loadState else {
            return XCTFail("Expected a loaded state after load, got \(String(describing: loadState)).")
        }
        XCTAssertEqual(loadedPayload, document.payload)

        let data = try await fileSystem.readData(at: path)
        XCTAssertEqual(data, try DocumentCodec().encode(document))
    }

    func testMissingDocumentIsNotConvertedToAnEmptyDocument() async throws {
        let store = DocumentStore(fileSystem: InMemoryFileSystemClient(), clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "missing", "metadata.json"])

        let state = await store.load(CodecPayload.self, documentType: .serverMetadata, at: path)

        guard case .missing = state else {
            return XCTFail("Missing storage must remain distinguishable from an empty payload.")
        }
    }

    func testAtomicReplaceFailurePreservesOriginalDocument() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "alpha", "metadata.json"])
        let original = try makeDocument(name: "original", count: 1)
        let replacement = try makeDocument(name: "replacement", count: 2)
        _ = await store.save(original, at: path)
        await fileSystem.setFailure(.replace)

        let state = await store.save(replacement, at: path)

        guard case .failed(let issue) = state else {
            return XCTFail("Replace failures must be reported as failed, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .replace)
        let retainedData = try await fileSystem.readData(at: path)
        XCTAssertEqual(retainedData, try DocumentCodec().encode(original))
    }

    func testFutureRevisionIsReadOnlyAndPreservesSource() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "future", "metadata.json"])
        let raw: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(99),
            "name": .string("future"),
            "count": .integer(1),
        ])
        let source = try DocumentCodec().encodeRaw(raw)
        await fileSystem.put(source, at: path)

        let state = await store.load(CodecPayload.self, documentType: .serverMetadata, at: path)

        guard case .unsupportedReadOnly(let document) = state else {
            return XCTFail("Future revisions must be read-only, got \(String(describing: state)).")
        }
        XCTAssertEqual(document.revision, 99)
        let retainedData = try await fileSystem.readData(at: path)
        let moveCount = await fileSystem.numberOfMoves
        XCTAssertEqual(retainedData, source)
        XCTAssertEqual(moveCount, 0)
    }

    func testMalformedDocumentIsQuarantinedAndNeverBecomesMissing() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "broken", "metadata.json"])
        await fileSystem.put(Data("{not-json".utf8), at: path)

        let state = await store.load(CodecPayload.self, documentType: .serverMetadata, at: path)

        guard case .repairRequired(let issue) = state else {
            return XCTFail("Malformed documents must require repair, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .quarantine)
        let sourceExists = await fileSystem.exists(at: path)
        let quarantineCount = await fileSystem.quarantineFileCount
        XCTAssertFalse(sourceExists)
        XCTAssertEqual(quarantineCount, 1)
    }

    func testDocumentTypeMismatchIsQuarantined() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "wrong", "metadata.json"])
        let wrongType: JSONValue = .object([
            "documentType": .string("server-index"),
            "entries": .array([]),
            "schemaVersion": .integer(1),
        ])
        await fileSystem.put(try DocumentCodec().encodeRaw(wrongType), at: path)

        let state = await store.load(CodecPayload.self, documentType: .serverMetadata, at: path)

        guard case .repairRequired(let issue) = state else {
            return XCTFail("A type mismatch must require repair, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.code, "document.typeMismatch")
        let sourceExists = await fileSystem.exists(at: path)
        XCTAssertFalse(sourceExists)
    }

    func testQuarantineRecordsUseUniqueOperationScopedPaths() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let firstPath = try ManagedPath(components: ["servers", "first", "metadata.json"])
        let secondPath = try ManagedPath(components: ["servers", "second", "metadata.json"])
        await fileSystem.put(Data("broken-1".utf8), at: firstPath)
        await fileSystem.put(Data("broken-2".utf8), at: secondPath)

        _ = await store.load(CodecPayload.self, documentType: .serverMetadata, at: firstPath)
        _ = await store.load(CodecPayload.self, documentType: .serverMetadata, at: secondPath)

        let quarantinePaths = await fileSystem.quarantineDocumentPaths
        XCTAssertEqual(quarantinePaths.count, 2)
        XCTAssertEqual(Set(quarantinePaths).count, 2)
    }

    func testMigrationBackupFailureKeepsOriginalDocument() async throws {
        let fileSystem = InMemoryFileSystemClient()
        await fileSystem.setFailure(.copy)
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [AddMarkerMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        let legacyData = try DocumentCodec().encodeRaw(legacy)
        await fileSystem.put(legacyData, at: path)

        let state = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)

        guard case .failed(let issue) = state else {
            return XCTFail("Backup failure must be failed, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .backup)
        let retainedData = try await fileSystem.readData(at: path)
        XCTAssertEqual(retainedData, legacyData)
    }

    func testTemporaryArtifactIsCleanedAfterWriteFailure() async throws {
        let fileSystem = InMemoryFileSystemClient()
        await fileSystem.setFailure(.synchronize)
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "alpha", "metadata.json"])

        let state = await store.save(try makeDocument(name: "alpha", count: 1), at: path)

        guard case .failed = state else {
            return XCTFail("Synchronize failure must be reported as failed, got \(String(describing: state)).")
        }
        let temporaryFileCount = await fileSystem.temporaryFileCount
        XCTAssertEqual(temporaryFileCount, 0)
    }

    func testMigrationSuccessCreatesRecoveryBackup() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let migration = AddMarkerMigration()
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [migration])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        let legacyData = try DocumentCodec().encodeRaw(legacy)
        await fileSystem.put(legacyData, at: path)

        let state = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)

        guard case .migrated(let payload, let backup) = state else {
            return XCTFail("Expected migration success, got \(String(describing: state)).")
        }
        XCTAssertEqual(payload.marker, "migrated")
        XCTAssertEqual(backup.fromRevision, 1)
        let backupData = try await fileSystem.readData(at: backup.path)
        let migratedData = await fileSystem.readDataIfPresent(at: path)
        let expectedData = try DocumentCodec().encodeRaw(
            .object([
                "count": .integer(1),
                "documentType": .string("server-metadata"),
                "marker": .string("migrated"),
                "name": .string("legacy"),
                "schemaVersion": .integer(2),
            ]))
        XCTAssertEqual(backupData, legacyData)
        XCTAssertEqual(migratedData, expectedData)
    }

    func testNextSuccessfulSaveCleansPreviousMigrationBackup() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [AddMarkerMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        await fileSystem.put(try DocumentCodec().encodeRaw(legacy), at: path)

        let migrationState = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)
        guard case .migrated(let payload, let backup) = migrationState else {
            return XCTFail("Expected migration success, got \(String(describing: migrationState)).")
        }
        let backupExistsBeforeSave = await fileSystem.exists(at: backup.path)
        XCTAssertTrue(backupExistsBeforeSave)

        let saveState = await store.save(
            try LoadStarDocument(
                documentType: .serverMetadata,
                revision: MigratingPayload.currentSchemaRevision,
                payload: payload
            ),
            at: path
        )

        guard case .loaded = saveState else {
            return XCTFail("Expected the subsequent save to succeed, got \(String(describing: saveState)).")
        }
        let backupExistsAfterSave = await fileSystem.exists(at: backup.path)
        XCTAssertFalse(backupExistsAfterSave)
    }

    func testMigrationBackupCleanupFailureKeepsBackupAndRecordsRetryableDiagnostic() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [AddMarkerMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        await fileSystem.put(try DocumentCodec().encodeRaw(legacy), at: path)

        let migrationState = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)
        guard case .migrated(let payload, let backup) = migrationState else {
            return XCTFail("Expected migration success, got \(String(describing: migrationState)).")
        }
        await fileSystem.setFailure(.remove)

        let saveState = await store.save(
            try LoadStarDocument(
                documentType: .serverMetadata,
                revision: MigratingPayload.currentSchemaRevision,
                payload: payload
            ),
            at: path
        )

        guard case .loaded = saveState else {
            return XCTFail("The saved document must remain valid when backup cleanup fails.")
        }
        let backupExistsAfterCleanupFailure = await fileSystem.exists(at: backup.path)
        XCTAssertTrue(backupExistsAfterCleanupFailure)
        let diagnostics = await store.recordedDiagnostics()
        XCTAssertEqual(diagnostics.last?.code, "migration.backupCleanupPending")
        XCTAssertEqual(diagnostics.last?.retryability, .retryable)
    }

    func testMigrationFailurePreservesOriginalAndBackup() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [ThrowingMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        let legacyData = try DocumentCodec().encodeRaw(legacy)
        await fileSystem.put(legacyData, at: path)

        let state = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)

        guard case .rolledBack(let issue, backup: let backup?) = state else {
            return XCTFail("Expected rollback state, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .migration)
        let retainedData = try await fileSystem.readData(at: path)
        let backupData = try await fileSystem.readData(at: backup.path)
        XCTAssertEqual(retainedData, legacyData)
        XCTAssertEqual(backupData, legacyData)
    }

    func testMigrationValidationFailurePreservesOriginalAndBackup() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [InvalidMarkerMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        let legacyData = try DocumentCodec().encodeRaw(legacy)
        await fileSystem.put(legacyData, at: path)

        let state = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)

        guard case .rolledBack(let issue, backup: let backup?) = state else {
            return XCTFail("Expected validation rollback, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .validation)
        let retainedData = try await fileSystem.readData(at: path)
        let backupData = try await fileSystem.readData(at: backup.path)
        XCTAssertEqual(retainedData, legacyData)
        XCTAssertEqual(backupData, legacyData)
    }

    func testMigrationCommitFailurePreservesOriginalAndBackup() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(
            fileSystem: fileSystem,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [AddMarkerMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let legacy: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "schemaVersion": .integer(1),
            "name": .string("legacy"),
            "count": .integer(1),
        ])
        let legacyData = try DocumentCodec().encodeRaw(legacy)
        await fileSystem.put(legacyData, at: path)
        await fileSystem.setFailure(.replace)

        let state = await store.load(MigratingPayload.self, documentType: .serverMetadata, at: path)

        guard case .rolledBack(let issue, backup: let backup?) = state else {
            return XCTFail("Expected commit rollback, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .replace)
        let retainedData = try await fileSystem.readData(at: path)
        let backupData = try await fileSystem.readData(at: backup.path)
        XCTAssertEqual(retainedData, legacyData)
        XCTAssertEqual(backupData, legacyData)
    }

    func testRecoveryRequiresMatchingExplicitConfirmation() async throws {
        let fileSystem = InMemoryFileSystemClient()
        let store = DocumentStore(fileSystem: fileSystem, clock: FixedClock())
        let destination = try ManagedPath(components: ["servers", "alpha", "metadata.json"])
        let candidatePath = try ManagedPath(components: ["quarantine", "migration-backups", "candidate.json"])
        let candidateID = try OperationID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let candidate = MigrationBackup(
            id: candidateID,
            documentType: .serverMetadata,
            fromRevision: 1,
            path: candidatePath,
            createdAt: FixedClock().now()
        )

        let state = await store.restoreLastKnownGood(
            CodecPayload.self,
            documentType: .serverMetadata,
            candidate: candidate,
            confirmation: RestoreConfirmation(candidateID: OperationID.new()),
            at: destination
        )

        guard case .failed(let issue) = state else {
            return XCTFail("Recovery without matching confirmation must fail, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.code, "recovery.confirmationMismatch")
        let readCount = await fileSystem.numberOfReads
        XCTAssertEqual(readCount, 0)
    }

    private func makeDocument(name: String, count: Int) throws -> LoadStarDocument<CodecPayload> {
        try LoadStarDocument(
            documentType: .serverMetadata,
            revision: CodecPayload.currentSchemaRevision,
            payload: CodecPayload(name: name, count: count)
        )
    }
}
// swiftlint:enable type_body_length

private struct CodecPayload: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    static let documentType = DocumentType.serverMetadata
    static let currentSchemaRevision = 1

    let name: String
    let count: Int

    func validate() throws {
        guard !name.isEmpty, count >= 0 else {
            throw DomainValidationError.invalidPolicy
        }
    }
}

private struct MigratingPayload: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    static let documentType = DocumentType.serverMetadata
    static let currentSchemaRevision = 2

    let name: String
    let count: Int
    let marker: String

    func validate() throws {
        guard !name.isEmpty, count >= 0, !marker.isEmpty else {
            throw DomainValidationError.invalidPolicy
        }
    }
}

private struct NestedCodecPayload: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    static let documentType = DocumentType.serverMetadata
    static let currentSchemaRevision = 1

    let settings: NestedCodecSettings

    func validate() throws {}
}

private struct NestedCodecSettings: Codable, Equatable, Sendable {
    let name: String
}

private struct AddMarkerMigration: MigrationStep {
    let documentType = DocumentType.serverMetadata
    let fromRevision = 1
    let toRevision = 2

    func migrate(_ input: JSONValue) throws -> JSONValue {
        guard case .object(let fields) = input else {
            throw DocumentCodecError.rootIsNotObject
        }

        var migrated = fields
        migrated["marker"] = .string("migrated")
        migrated["schemaVersion"] = .integer(2)
        return .object(migrated)
    }
}

private struct ThrowingMigration: MigrationStep {
    let documentType = DocumentType.serverMetadata
    let fromRevision = 1
    let toRevision = 2

    func migrate(_: JSONValue) throws -> JSONValue {
        throw MigrationCoordinatorError.cycleDetected
    }
}

private struct InvalidMarkerMigration: MigrationStep {
    let documentType = DocumentType.serverMetadata
    let fromRevision = 1
    let toRevision = 2

    func migrate(_ input: JSONValue) throws -> JSONValue {
        guard case .object(var fields) = input else {
            throw DocumentCodecError.rootIsNotObject
        }
        fields["marker"] = .string("")
        fields["schemaVersion"] = .integer(2)
        return .object(fields)
    }
}

private enum FakeFileSystemOperation: Sendable {
    case write
    case synchronize
    case replace
    case copy
    case move
    case remove
}

private actor InMemoryFileSystemClient: FileSystemClient {
    private var files: [ManagedPath: Data] = [:]
    private var directories: Set<ManagedPath> = []
    private var failure: FakeFileSystemOperation?

    private(set) var numberOfMoves = 0
    private(set) var numberOfReads = 0

    func setFailure(_ operation: FakeFileSystemOperation?) {
        failure = operation
    }

    func put(_ data: Data, at path: ManagedPath) {
        files[path] = data
    }

    func readData(at path: ManagedPath) throws -> Data {
        numberOfReads += 1
        guard let data = files[path] else {
            throw FileSystemError.notFound(path)
        }
        return data
    }

    func readDataIfPresent(at path: ManagedPath) -> Data? {
        files[path]
    }

    func writeData(_ data: Data, at path: ManagedPath) throws {
        try failIfConfigured(.write, target: path)
        files[path] = data
    }

    func synchronize(at path: ManagedPath) throws {
        try failIfConfigured(.synchronize, target: path)
    }

    func createDirectory(at path: ManagedPath) throws {
        directories.insert(path)
    }

    func replaceItem(at destination: ManagedPath, with source: ManagedPath) throws {
        try failIfConfigured(.replace, target: destination)
        guard let data = files.removeValue(forKey: source) else {
            throw FileSystemError.notFound(source)
        }
        files[destination] = data
    }

    func copyItem(at source: ManagedPath, to destination: ManagedPath) throws {
        try failIfConfigured(.copy, target: destination)
        guard let data = files[source] else {
            throw FileSystemError.notFound(source)
        }
        files[destination] = data
    }

    func moveItem(at source: ManagedPath, to destination: ManagedPath) throws {
        try failIfConfigured(.move, target: destination)
        guard let data = files.removeValue(forKey: source) else {
            throw FileSystemError.notFound(source)
        }
        files[destination] = data
        numberOfMoves += 1
    }

    func removeItem(at path: ManagedPath) throws {
        try failIfConfigured(.remove, target: path)
        files.removeValue(forKey: path)
        directories.remove(path)
    }

    func exists(at path: ManagedPath) -> Bool {
        files[path] != nil || directories.contains(path)
    }

    func metadata(at path: ManagedPath) throws -> FileMetadata {
        if let data = files[path] {
            return FileMetadata(
                size: Int64(data.count), modificationDate: nil, isDirectory: false, isSymbolicLink: false)
        }
        if directories.contains(path) {
            return FileMetadata(size: 0, modificationDate: nil, isDirectory: true, isSymbolicLink: false)
        }
        throw FileSystemError.notFound(path)
    }

    func listDirectory(at path: ManagedPath) -> [ManagedPath] {
        files.keys.filter { $0.parent == path }
    }

    var quarantineFileCount: Int {
        files.keys.filter { $0.relativePath.hasPrefix("quarantine/documents/") }.count
    }

    var quarantineDocumentPaths: [ManagedPath] {
        files.keys.filter { $0.relativePath.hasPrefix("quarantine/documents/") }.sorted {
            $0.relativePath < $1.relativePath
        }
    }

    var temporaryFileCount: Int {
        files.keys.filter { $0.components.last?.hasSuffix(".tmp") == true }.count
    }

    private func failIfConfigured(_ operation: FakeFileSystemOperation, target: ManagedPath) throws {
        guard failure == operation else {
            return
        }
        throw FileSystemError.operationFailed(code: "fake.\(String(describing: operation))", target: target)
    }
}

private struct FixedClock: Clock {
    let value = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date {
        value
    }
}

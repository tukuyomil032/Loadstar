import Foundation
import LoadStarDomain
import LoadStarPersistence
import LoadStarPlatform
import XCTest

@testable import LoadStarServices

final class LoadStarIntegrationTests: XCTestCase {
    func testManagedRootPersistsIndexAndResolvesMetadataInDisplayOrder() async throws {
        let applicationSupport = temporaryDirectory(named: "catalog")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let root = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        let client = try root.fileSystemClient()
        let store = DocumentStore(fileSystem: client, clock: FixedClock())
        let firstID = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let secondID = ServerID(rawValue: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let indexPath = try ManagedPath(components: ["servers", "index.json"])

        let index = try LoadStarDocument(
            documentType: .serverIndex,
            revision: ServerIndex.currentSchemaRevision,
            payload: ServerIndex(entries: [ServerIndexEntry(id: secondID), ServerIndexEntry(id: firstID)])
        )
        _ = await store.save(index, at: indexPath)
        _ = await store.save(try metadataDocument(id: firstID, name: "First"), at: try metadataPath(for: firstID))
        _ = await store.save(try metadataDocument(id: secondID, name: "Second"), at: try metadataPath(for: secondID))

        let state = await store.load(ServerIndex.self, documentType: .serverIndex, at: indexPath)
        guard case .loaded(let loadedIndex) = state else {
            return XCTFail("Expected the server index to load, got \(String(describing: state)).")
        }
        var names: [String] = []
        for entry in loadedIndex.entries {
            let metadataState = await store.load(
                ServerMetadata.self,
                documentType: .serverMetadata,
                at: try metadataPath(for: entry.id)
            )
            guard case .loaded(let metadata) = metadataState else {
                throw IntegrationTestError.metadataDidNotLoad
            }
            names.append(metadata.identity.displayName)
        }
        XCTAssertEqual(names, ["Second", "First"])
    }

    func testUnknownMetadataFieldsSurviveAnIntegrationReadWrite() async throws {
        let applicationSupport = temporaryDirectory(named: "unknown")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let root = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        let client = try root.fileSystemClient()
        let codec = DocumentCodec()
        let serverID = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let document = try metadataDocument(
            id: serverID,
            name: "Unknown Field Server",
            unknownFields: ["futureSection": .object(["enabled": .boolean(true)])]
        )
        let path = try metadataPath(for: serverID)
        try await client.writeData(codec.encode(document), at: path)

        let raw = try codec.decodeRaw(try await client.readData(at: path))
        let decoded = try codec.decode(
            ServerMetadata.self, from: try codec.encodeRaw(raw), expectedDocumentType: .serverMetadata)
        let rewritten = try codec.encode(decoded)

        XCTAssertEqual(decoded.unknownFields["futureSection"], .object(["enabled": .boolean(true)]))
        XCTAssertEqual(try codec.decodeRaw(rewritten), raw)
    }

    func testMigrationFailureKeepsOriginalManagedDocument() async throws {
        let applicationSupport = temporaryDirectory(named: "migration")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let root = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        let client = try root.fileSystemClient()
        let store = DocumentStore(
            fileSystem: client,
            clock: FixedClock(),
            migrations: MigrationCoordinator(steps: [ThrowingMigration()])
        )
        let path = try ManagedPath(components: ["servers", "legacy", "metadata.json"])
        let original: JSONValue = .object([
            "documentType": .string("server-metadata"),
            "name": .string("legacy"),
            "schemaVersion": .integer(1),
        ])
        let originalData = try DocumentCodec().encodeRaw(original)
        try await client.writeData(originalData, at: path)

        let state = await store.load(IntegrationMigratingPayload.self, documentType: .serverMetadata, at: path)

        guard case .rolledBack(let issue, backup: let backup?) = state else {
            return XCTFail("Expected a recoverable migration failure, got \(String(describing: state)).")
        }
        XCTAssertEqual(issue.stage, .migration)
        let retainedData = try await client.readData(at: path)
        let backupData = try await client.readData(at: backup.path)
        XCTAssertEqual(retainedData, originalData)
        XCTAssertEqual(backupData, originalData)
    }

    func testCorruptDocumentIsQuarantinedAndConfirmedCandidateCanBeRestored() async throws {
        let applicationSupport = temporaryDirectory(named: "recovery")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let root = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        let client = try root.fileSystemClient()
        let store = DocumentStore(fileSystem: client, clock: FixedClock())
        let path = try ManagedPath(components: ["servers", "broken", "metadata.json"])
        try await client.writeData(Data("not-json".utf8), at: path)

        let repairState = await store.load(ServerMetadata.self, documentType: .serverMetadata, at: path)
        guard case .repairRequired = repairState else {
            return XCTFail("Expected corrupt data to enter repair state, got \(String(describing: repairState)).")
        }

        let candidateID = try OperationID(rawValue: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let candidatePath = try ManagedPath(components: ["quarantine", "migration-backups", "candidate.json"])
        let candidateData = try DocumentCodec().encode(
            try metadataDocument(
                id: ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
                name: "Recovered"
            ))
        try await client.writeData(candidateData, at: candidatePath)
        let candidate = MigrationBackup(
            id: candidateID,
            documentType: .serverMetadata,
            fromRevision: 1,
            path: candidatePath,
            createdAt: FixedClock().now()
        )

        let rejected = await store.restoreLastKnownGood(
            ServerMetadata.self,
            documentType: .serverMetadata,
            candidate: candidate,
            confirmation: RestoreConfirmation(candidateID: OperationID.new()),
            at: path
        )
        guard case .failed = rejected else {
            return XCTFail("Recovery without confirmation must be rejected.")
        }
        let restored = await store.restoreLastKnownGood(
            ServerMetadata.self,
            documentType: .serverMetadata,
            candidate: candidate,
            confirmation: RestoreConfirmation(candidateID: candidateID),
            at: path
        )
        guard case .loaded(let metadata) = restored else {
            return XCTFail("Confirmed recovery should load the candidate, got \(String(describing: restored)).")
        }
        XCTAssertEqual(metadata.identity.displayName, "Recovered")
    }

    func testDebugNamespaceCannotReadProductionData() async throws {
        let applicationSupport = temporaryDirectory(named: "isolation")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let productionRoot = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        let debugRoot = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .debug)
        let productionClient = try productionRoot.fileSystemClient()
        let debugClient = try debugRoot.fileSystemClient()
        let path = try ManagedPath(components: ["servers", "same-id", "metadata.json"])
        try await productionClient.writeData(Data("production".utf8), at: path)

        let debugInitiallyExists = try await debugClient.exists(at: path)
        try await debugClient.writeData(Data("debug".utf8), at: path)
        let productionData = try await productionClient.readData(at: path)
        let debugData = try await debugClient.readData(at: path)
        XCTAssertFalse(debugInitiallyExists)
        XCTAssertEqual(productionData, Data("production".utf8))
        XCTAssertEqual(debugData, Data("debug".utf8))
    }

    func testPathAndArchiveValidationStopBeforeCommit() throws {
        let validator = ArchiveEntryValidator()
        XCTAssertThrowsError(try ManagedPath(components: ["servers", "..", "metadata.json"]))
        XCTAssertThrowsError(try validator.validate([ArchiveEntry(path: "../../escape", kind: .regularFile)]))
        XCTAssertThrowsError(try validator.validate([ArchiveEntry(path: "link", kind: .hardLink)]))
    }

    func testSecretsRemainOpaqueToOrdinaryDocumentEncoding() throws {
        let secret = SecretValue(data: Data("opaque".utf8))
        XCTAssertEqual(String(describing: secret), "<redacted>")
        XCTAssertEqual(String(reflecting: secret), "<redacted>")
        let payload = try metadataDocument(
            id: ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"),
            name: "No Secret"
        )
        let encoded = try DocumentCodec().encode(payload)
        XCTAssertFalse((String(bytes: encoded, encoding: .utf8) ?? "").contains("opaque"))
    }

    func testFixtureProcessEmitsDeterministicHumanAndEventTraces() throws {
        guard let fixturePath = FixtureExecutableLocator.path() else {
            throw XCTSkip("LOADSTAR_FIXTURE_SERVER_PATH is not set; fixture-dependent tests are skipped.")
        }

        let scenario = LoadStarFixtureScenario(
            readyAfterMillis: 5_000,
            stdout: ["fixture started"],
            stderr: ["fixture diagnostic"],
            invalidUTF8: true
        )
        let scenarioURL = temporaryDirectory(named: "fixture").appendingPathComponent("scenario.json")
        try FileManager.default.createDirectory(
            at: scenarioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scenarioURL.deletingLastPathComponent()) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(scenario).write(to: scenarioURL)

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: fixturePath)
        process.arguments = ["--scenario", scenarioURL.path, "--port", "25565"]
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        Thread.sleep(forTimeInterval: 1.0)
        process.terminate()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let diagnostic = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(output.contains("LoadStar fixture started"))
        XCTAssertTrue(output.contains("LOADSTAR_EVENT {\"kind\":\"started\"}"))
        XCTAssertTrue(output.contains("\u{FFFD}"))
        XCTAssertTrue(diagnostic.contains("fixture diagnostic"))
    }

    func testFixtureReadyScenarioSpeaksMinecraftServerListPing() async throws {
        guard let fixturePath = FixtureExecutableLocator.path() else {
            throw XCTSkip("LOADSTAR_FIXTURE_SERVER_PATH is not set; fixture-dependent tests are skipped.")
        }

        let scenarioURL = temporaryDirectory(named: "slp").appendingPathComponent("scenario.json")
        try FileManager.default.createDirectory(
            at: scenarioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scenarioURL.deletingLastPathComponent()) }
        try JSONEncoder().encode(LoadStarFixtureScenario(readyAfterMillis: 0)).write(to: scenarioURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: fixturePath)
        process.arguments = ["--scenario", scenarioURL.path, "--port", "25566"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        defer {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
        }
        try await Task.sleep(for: .milliseconds(150))

        let ping = try await NetworkServerListPingClient().ping(
            host: "127.0.0.1", port: 25_566, timeout: .seconds(2))
        XCTAssertEqual(ping.versionName, "LoadStar Fixture")
        XCTAssertEqual(ping.playersOnline, 0)
    }

    private func metadataPath(for id: ServerID) throws -> ManagedPath {
        try ManagedPath(components: ["servers", id.rawValue, "metadata.json"])
    }

    private func metadataDocument(
        id: ServerID,
        name: String,
        unknownFields: UnknownFields = [:]
    ) throws -> LoadStarDocument<ServerMetadata> {
        let metadata = ServerMetadata(
            identity: try ServerIdentity(id: id, displayName: name, group: "Development"),
            runtimeConfiguration: try RuntimeConfiguration(
                memoryMiB: 2_048,
                jarFileName: "server.jar",
                javaSelection: .systemDefault,
                jvmArguments: JVMArguments(raw: "-Xmx2G", validatedTokens: ["-Xmx2G"], validation: .valid),
                eulaAccepted: true
            ),
            policies: ServerPolicies(
                crashRecovery: try CrashRecoveryPolicy(mode: .prompt),
                backup: try BackupPolicy(schedule: .daily(hour: 3, minute: 0), retentionCount: 3),
                notifications: NotificationPolicy(enabled: true, highCPUAlertsEnabled: false)
            ),
            provenance: Provenance(source: .userCreated, observedAt: FixedClock().now(), verification: .verified),
            timestamps: MetadataTimestamps(
                registeredAt: FixedClock().now(),
                configurationChangedAt: FixedClock().now(),
                lastVerifiedAt: FixedClock().now()
            )
        )
        return try LoadStarDocument(
            documentType: .serverMetadata,
            revision: ServerMetadata.currentSchemaRevision,
            payload: metadata,
            unknownFields: unknownFields
        )
    }
}

private enum IntegrationTestError: Error {
    case metadataDidNotLoad
}

private struct IntegrationMigratingPayload: Codable, Sendable, LoadStarDocumentPayload {
    static let documentType = DocumentType.serverMetadata
    static let currentSchemaRevision = 2

    let name: String
    let marker: String

    func validate() throws {
        guard !name.isEmpty, !marker.isEmpty else {
            throw DomainValidationError.invalidPolicy
        }
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

private struct FixedClock: Clock {
    let value = Date(timeIntervalSince1970: 1_700_000_000)

    func now() -> Date {
        value
    }
}

private func temporaryDirectory(named name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("LoadStarIntegrationTests-\(name)-\(UUID().uuidString)", isDirectory: true)
}

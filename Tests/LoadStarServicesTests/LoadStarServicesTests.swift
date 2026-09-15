import CryptoKit
import Foundation
import LoadStarDomain
import LoadStarPlatform
import XCTest

import struct LoadStarDomain.SHA256Digest

@testable import LoadStarServices

final class LoadStarServicesTests: XCTestCase {
    func testProductNameIsExposedByServices() {
        XCTAssertEqual(LoadStarServices.productName, "LoadStar")
    }

    func testEULARequiresManualConsentAndDoesNotWriteForAutomaticIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = ManagedRoot(applicationSupportURL: rootURL, namespace: .debug)
        let fileSystem = try root.fileSystemClient()
        let serverDirectory = try ManagedPath.serverDirectory(
            for: ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"))
        let service = FileEULAService(fileSystem: fileSystem)

        let initialState = await service.state(for: serverDirectory)
        XCTAssertEqual(initialState, .required)
        do {
            _ = try await service.accept(for: serverDirectory, intent: .automatic)
            XCTFail("Automatic launch must never write EULA consent.")
        } catch let error as EULAServiceError {
            XCTAssertEqual(error, .automaticConsentForbidden)
        }
        let unchangedState = await service.state(for: serverDirectory)
        XCTAssertEqual(unchangedState, .required)
        XCTAssertFalse(service.bundledText().english.isEmpty)
        XCTAssertFalse(service.bundledText().japaneseReference.isEmpty)
    }

    func testPreflightBlocksJarChecksumMismatchWithoutChangingMetadata() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = ManagedRoot(applicationSupportURL: rootURL, namespace: .debug)
        let fileSystem = try root.fileSystemClient()
        let serverID = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let serverDirectory = try ManagedPath.serverDirectory(for: serverID)
        let jarPath = try serverDirectory.appending("server.jar")
        try await fileSystem.writeData(Data("fixture jar".utf8), at: jarPath)
        try await fileSystem.writeData(Data("eula=true\n".utf8), at: try serverDirectory.appending("eula.txt"))

        let validator = JavaExecutableValidator(injectedVerification: { _ in
            JavaVerification(majorVersion: 21, vendor: "Test", verification: .verified, verifiedAt: nil)
        })
        let java = JavaInstallation(
            identifier: "test", executableURL: URL(fileURLWithPath: "/tmp/java"), majorVersion: 21)
        let provider = MacOSJavaRuntimeProvider(installations: [java], validator: validator)
        let wrongDigest = try SHA256Digest(validating: String(repeating: "0", count: 64))
        let artifact = ArtifactIdentity(
            kind: .serverJar,
            source: .imported,
            filename: "server.jar",
            version: nil,
            loader: nil,
            gameVersion: nil,
            checksum: wrongDigest,
            provenance: Provenance(source: .imported, verification: .verified)
        )
        let configuration = try RuntimeConfiguration(
            memoryMiB: 2048,
            jarFileName: "server.jar",
            javaSelection: .managed(identifier: "test"),
            jvmArguments: JVMArguments(raw: "", validation: .valid),
            eulaAccepted: true,
            jarArtifact: artifact
        )
        let metadata = ServerMetadata(
            identity: try ServerIdentity(id: serverID, displayName: "Fixture"),
            runtimeConfiguration: configuration,
            policies: ServerPolicies(
                crashRecovery: try CrashRecoveryPolicy(mode: .prompt),
                backup: try BackupPolicy(schedule: .disabled, retentionCount: 1),
                notifications: NotificationPolicy(enabled: true, highCPUAlertsEnabled: false)
            ),
            provenance: Provenance(source: .userCreated, verification: .verified),
            timestamps: MetadataTimestamps(registeredAt: Date(), configurationChangedAt: Date())
        )
        let service = LaunchPreflightService(
            javaProvider: provider,
            fileSystem: fileSystem,
            eulaService: FileEULAService(fileSystem: fileSystem),
            serverDirectory: serverDirectory
        )

        let report = await service.evaluate(metadata: metadata, intent: .manual)
        guard case .blocked(let issue) = report.result else {
            return XCTFail("A checksum mismatch must block launch.")
        }
        XCTAssertEqual(issue.code, "server.start.jar.checksumMismatch")
        XCTAssertEqual(metadata.runtimeConfiguration.jarArtifact?.checksum, wrongDigest)
    }

    func testCoordinatorStartsWithRunningAndProbingWhenSLPIsUnavailable() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = ManagedRoot(applicationSupportURL: rootURL, namespace: .debug)
        let fileSystem = try root.fileSystemClient()
        let serverID = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let serverDirectory = try ManagedPath.serverDirectory(for: serverID)
        try await fileSystem.writeData(Data("fixture jar".utf8), at: try serverDirectory.appending("server.jar"))
        try await fileSystem.writeData(Data("eula=true\n".utf8), at: try serverDirectory.appending("eula.txt"))

        let metadata = try makeMetadata(serverID: serverID)
        let processController = StubProcessController()
        let coordinator = makeCoordinator(
            metadata: metadata,
            fileSystem: fileSystem,
            processController: processController,
            pingClient: FailingPingClient(),
            rootURL: rootURL
        )

        let result = await coordinator.start(serverID: serverID, intent: .manual)
        guard case .accepted(let snapshot) = result else {
            return XCTFail("A valid process should start even if SLP cannot connect.")
        }
        XCTAssertEqual(snapshot.lifecycle, .running)
        XCTAssertEqual(snapshot.readiness, .probing)

        try await Task.sleep(for: .milliseconds(50))
        let current = await coordinator.snapshots()[serverID]
        XCTAssertEqual(current?.lifecycle, .running)
        guard case .unconnected = current?.readiness else {
            return XCTFail("SLP failure should become unconnected while preserving the process.")
        }
        XCTAssertTrue(current?.capabilities.canStop == true)
        let didLaunch = await processController.didLaunch
        XCTAssertTrue(didLaunch)
    }

    func testCoordinatorRequiresConfirmationBeforeMissingEULA() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = ManagedRoot(applicationSupportURL: rootURL, namespace: .debug)
        let fileSystem = try root.fileSystemClient()
        let serverID = ServerID(rawValue: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let serverDirectory = try ManagedPath.serverDirectory(for: serverID)
        try await fileSystem.writeData(Data("fixture jar".utf8), at: try serverDirectory.appending("server.jar"))

        let coordinator = makeCoordinator(
            metadata: try makeMetadata(serverID: serverID),
            fileSystem: fileSystem,
            processController: StubProcessController(),
            pingClient: FailingPingClient(),
            rootURL: rootURL
        )
        let result = await coordinator.start(serverID: serverID, intent: .automatic)

        guard case .needsConfirmation(let requirement) = result else {
            return XCTFail("Automatic launch must stop at the EULA confirmation boundary.")
        }
        XCTAssertEqual(requirement.code, "server.eula.required")
    }

    func testCoordinatorStopUsesExplicitForceDecisionAndCancelKeepsProcess() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let root = ManagedRoot(applicationSupportURL: rootURL, namespace: .debug)
        let fileSystem = try root.fileSystemClient()
        let serverID = ServerID(rawValue: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let serverDirectory = try ManagedPath.serverDirectory(for: serverID)
        try await fileSystem.writeData(Data("fixture jar".utf8), at: try serverDirectory.appending("server.jar"))
        try await fileSystem.writeData(Data("eula=true\n".utf8), at: try serverDirectory.appending("eula.txt"))
        let processController = StubProcessController()
        let coordinator = makeCoordinator(
            metadata: try makeMetadata(serverID: serverID),
            fileSystem: fileSystem,
            processController: processController,
            pingClient: FailingPingClient(),
            rootURL: rootURL
        )
        guard case .accepted = await coordinator.start(serverID: serverID, intent: .manual) else {
            return XCTFail("The fixture server should start.")
        }

        _ = await coordinator.stop(serverID: serverID)
        _ = await coordinator.decideStopTimeout(serverID: serverID, decision: .cancel)
        let cancelledSnapshot = await coordinator.snapshots()[serverID]
        XCTAssertEqual(cancelledSnapshot?.lifecycle, .running)
        let gracefulStopCount = await processController.gracefulStopCount
        XCTAssertEqual(gracefulStopCount, 1)

        _ = await coordinator.decideStopTimeout(serverID: serverID, decision: .force)
        try await Task.sleep(for: .milliseconds(50))
        let forceStopCount = await processController.forceStopCount
        XCTAssertEqual(forceStopCount, 1)
    }

    private func makeCoordinator(
        metadata: ServerMetadata,
        fileSystem: any FileSystemClient,
        processController: StubProcessController,
        pingClient: any ServerListPingClient,
        rootURL: URL
    ) -> ServerLifecycleCoordinator {
        let serverID = metadata.identity.id
        let java = JavaInstallation(
            identifier: "test", executableURL: URL(fileURLWithPath: "/tmp/java"), majorVersion: 21)
        let provider = MacOSJavaRuntimeProvider(
            installations: [java],
            validator: JavaExecutableValidator(injectedVerification: { _ in
                JavaVerification(majorVersion: 21, vendor: "Test", verification: .verified, verifiedAt: nil)
            })
        )
        return ServerLifecycleCoordinator(
            metadataRepository: StubMetadataRepository(metadata: metadata),
            fileSystem: fileSystem,
            javaProvider: provider,
            processController: processController,
            pingClient: pingClient,
            eulaService: FileEULAService(fileSystem: fileSystem),
            checkpointStore: InMemoryLifecycleCheckpointStore(),
            sleeper: CancelledSleeper(),
            serverDirectoryURL: { _ in rootURL.appendingPathComponent("server-\(serverID.rawValue)", isDirectory: true)
            }
        )
    }

    private func makeMetadata(serverID: ServerID) throws -> ServerMetadata {
        ServerMetadata(
            identity: try ServerIdentity(id: serverID, displayName: "Fixture"),
            runtimeConfiguration: try RuntimeConfiguration(
                memoryMiB: 2048,
                jarFileName: "server.jar",
                javaSelection: .managed(identifier: "test"),
                jvmArguments: JVMArguments(raw: "", validation: .valid),
                eulaAccepted: true
            ),
            policies: ServerPolicies(
                crashRecovery: try CrashRecoveryPolicy(mode: .prompt),
                backup: try BackupPolicy(schedule: .disabled, retentionCount: 1),
                notifications: NotificationPolicy(enabled: true, highCPUAlertsEnabled: false)
            ),
            provenance: Provenance(source: .userCreated, verification: .verified),
            timestamps: MetadataTimestamps(registeredAt: Date(), configurationChangedAt: Date())
        )
    }
}

private struct StubMetadataRepository: ServerMetadataRepository {
    let metadata: ServerMetadata

    func load(serverID: ServerID) async throws -> ServerMetadata {
        guard metadata.identity.id == serverID else { throw EULAServiceError.writeFailed }
        return metadata
    }

    func save(_: ServerMetadata, serverID _: ServerID) async throws {}
}

private actor StubProcessController: ProcessController {
    private(set) var didLaunch = false
    private(set) var gracefulStopCount = 0
    private(set) var forceStopCount = 0
    private var continuation: AsyncStream<ProcessEvent>.Continuation?
    private let session = ProcessSession(
        id: ProcessSessionID(rawValue: "fixture-session"),
        identity: ProcessIdentity(pid: 123, startedAt: Date(timeIntervalSince1970: 1), executableReference: "java")
    )

    func launch(_: ProcessLaunchRequest) async throws -> ProcessSession {
        didLaunch = true
        return session
    }

    func events(for _: ProcessSessionID) async -> AsyncStream<ProcessEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func requestGracefulStop(_: ProcessSessionID) async throws { gracefulStopCount += 1 }
    func requestForceStop(_: ProcessSessionID) async throws { forceStopCount += 1 }
    func waitForExit(_: ProcessSessionID) async -> ProcessExit? { nil }
}

private struct FailingPingClient: ServerListPingClient {
    func ping(host _: String, port _: Int, timeout _: Duration) async throws -> ServerPing {
        throw ServerListPingError.timeout
    }
}

private struct CancelledSleeper: LifecycleSleeper {
    func sleep(for _: Duration) async throws {
        throw CancellationError()
    }
}

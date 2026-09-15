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
}

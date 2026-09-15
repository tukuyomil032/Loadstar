import Foundation
import LoadStarDomain
import XCTest

@testable import LoadStarPlatform

final class LoadStarPlatformTests: XCTestCase {
    func testMinimumMacOSMajorVersion() {
        XCTAssertEqual(LoadStarPlatform.minimumMacOSMajorVersion, 26)
    }

    func testProductionAndDebugRootsAreDistinct() throws {
        let applicationSupport = temporaryDirectory(named: "roots")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }

        let production = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        let debug = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .debug)

        XCTAssertNotEqual(production.rootURL, debug.rootURL)
        XCTAssertNotEqual(production.namespace.keychainService, debug.namespace.keychainService)
        XCTAssertEqual(production.rootURL.lastPathComponent, "LoadStar")
        XCTAssertEqual(debug.rootURL.lastPathComponent, "LoadStar-Debug")
    }

    func testMissingRootIsCreatedAndLocalClientRoundTripsData() async throws {
        let applicationSupport = temporaryDirectory(named: "filesystem")
        defer { try? FileManager.default.removeItem(at: applicationSupport) }
        let root = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .debug)

        _ = try root.ensureExists()
        let client = try root.fileSystemClient()
        let path = try ManagedPath(components: ["servers", "alpha", "metadata.json"])
        let data = Data("payload".utf8)

        try await client.writeData(data, at: path)

        let loadedData = try await client.readData(at: path)
        let parent = try ManagedPath(components: ["servers", "alpha"])
        let children = try await client.listDirectory(at: parent)
        XCTAssertEqual(loadedData, data)
        XCTAssertEqual(children, [path])
    }

    func testManagedPathRejectsAbsoluteTraversalAndControlCharacters() {
        XCTAssertThrowsError(try ManagedPath(components: ["/absolute"]))
        XCTAssertThrowsError(try ManagedPath(components: ["servers", "..", "metadata.json"]))
        XCTAssertThrowsError(try ManagedPath(components: ["servers", "name\u{0000}", "metadata.json"]))
        XCTAssertThrowsError(try ManagedPath(components: ["servers", "name/metadata.json"]))
    }

    func testNestedSymlinkEscapeIsRejected() throws {
        let applicationSupport = temporaryDirectory(named: "symlink")
        let outside = temporaryDirectory(named: "outside")
        defer {
            try? FileManager.default.removeItem(at: applicationSupport)
            try? FileManager.default.removeItem(at: outside)
        }

        let root = ManagedRoot(applicationSupportURL: applicationSupport, namespace: .production)
        try root.ensureExists()
        let symlink = root.rootURL.appendingPathComponent("escape", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        let path = try ManagedPath(components: ["escape", "secret.json"])
        XCTAssertThrowsError(try root.resolve(path)) { error in
            guard case .symbolicLinkEscape(path) = error as? ManagedPathValidationError else {
                return XCTFail("Expected a symbolic link escape error, got \(error).")
            }
        }
    }

    func testArchiveValidatorRejectsUnsafeEntriesAndDuplicates() throws {
        let validator = ArchiveEntryValidator()

        XCTAssertThrowsError(try validator.validate([ArchiveEntry(path: "/etc/passwd", kind: .regularFile)])) { error in
            XCTAssertEqual(error as? ArchiveEntryValidationError, .absolutePath("/etc/passwd"))
        }
        XCTAssertThrowsError(try validator.validate([ArchiveEntry(path: "../escape", kind: .regularFile)])) { error in
            XCTAssertEqual(error as? ArchiveEntryValidationError, .traversal("../escape"))
        }
        XCTAssertThrowsError(try validator.validate([ArchiveEntry(path: "link", kind: .symbolicLink)])) { error in
            XCTAssertEqual(error as? ArchiveEntryValidationError, .linkEntry("link", .symbolicLink))
        }
        XCTAssertThrowsError(
            try validator.validate([
                ArchiveEntry(path: "mods/a.jar", kind: .regularFile),
                ArchiveEntry(path: "mods/a.jar", kind: .regularFile),
            ])
        ) { error in
            guard case .duplicatePath(let path) = error as? ArchiveEntryValidationError else {
                return XCTFail("Expected duplicate path error, got \(error).")
            }
            XCTAssertEqual(path.relativePath, "mods/a.jar")
        }
    }

    func testArchiveValidatorAcceptsSafeEntriesAndRejectsChecksumMismatch() throws {
        let validator = ArchiveEntryValidator()
        let entries = try validator.validate([
            ArchiveEntry(path: "mods", kind: .directory),
            ArchiveEntry(path: "mods/a.jar", kind: .regularFile),
        ])
        XCTAssertEqual(entries.map(\.relativePath), ["mods", "mods/a.jar"])

        let expected = try SHA256Digest(validating: String(repeating: "a", count: 64))
        let actual = try SHA256Digest(validating: String(repeating: "b", count: 64))
        let path = try ManagedPath(components: ["mods", "a.jar"])
        XCTAssertThrowsError(try validator.validateChecksum(expected: expected, actual: actual, path: path)) { error in
            XCTAssertEqual(
                error as? ArchiveEntryValidationError, .checksumMismatch(path, expected: expected, actual: actual))
        }
    }

    func testFakeKeychainSeparatesNamespaceAndPurpose() async throws {
        let keychain = FakeKeychainClient()
        let serverID = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let productionKey = SecretKey(namespace: .production, serverID: serverID, purpose: .ngrokToken)
        let debugKey = SecretKey(namespace: .debug, serverID: serverID, purpose: .ngrokToken)
        let productionValue = SecretValue(data: Data("production-secret".utf8))
        let debugValue = SecretValue(data: Data("debug-secret".utf8))

        await keychain.write(productionValue, for: productionKey)
        await keychain.write(debugValue, for: debugKey)

        let loadedProduction = await keychain.read(for: productionKey)
        let loadedDebug = await keychain.read(for: debugKey)
        XCTAssertEqual(loadedProduction?.withData { $0 }, Data("production-secret".utf8))
        XCTAssertEqual(loadedDebug?.withData { $0 }, Data("debug-secret".utf8))

        await keychain.delete(for: productionKey)
        let deletedProduction = await keychain.read(for: productionKey)
        let retainedDebug = await keychain.read(for: debugKey)
        XCTAssertNil(deletedProduction)
        XCTAssertNotNil(retainedDebug)
    }

    func testSecretsAndDiagnosticsAreRedacted() throws {
        let value = SecretValue(data: Data("super-secret-token".utf8))
        XCTAssertEqual(String(describing: value), "<redacted>")
        XCTAssertEqual(String(reflecting: value), "<redacted>")

        let detail = DiagnosticRedactor().redact(
            "Authorization: Bearer super-secret /Users/hosiyomi322/private/file.json token=another-secret"
        )
        XCTAssertFalse(detail.contains("super-secret"))
        XCTAssertFalse(detail.contains("another-secret"))
        XCTAssertFalse(detail.contains("/Users/hosiyomi322"))
        XCTAssertTrue(detail.contains("<redacted>"))
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LoadStarPlatformTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    }
}

private actor FakeKeychainClient: KeychainClient {
    private var values: [SecretKey: SecretValue] = [:]

    func read(for key: SecretKey) -> SecretValue? {
        values[key]
    }

    func write(_ value: SecretValue, for key: SecretKey) {
        values[key] = value
    }

    func delete(for key: SecretKey) {
        values.removeValue(forKey: key)
    }
}

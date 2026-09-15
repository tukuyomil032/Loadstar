import XCTest

@testable import LoadStarDomain

final class LoadStarDomainTests: XCTestCase {
    func testProductNameIsStable() {
        XCTAssertEqual(LoadStarDomain.productName, "LoadStar")
    }

    func testServerIDNormalizesCanonicalUUIDToLowercase() throws {
        let id = try ServerID(validating: "550E8400-E29B-41D4-A716-446655440000")

        XCTAssertEqual(id.rawValue, "550e8400-e29b-41d4-a716-446655440000")
    }

    func testServerIDRejectsNonV4UUID() {
        XCTAssertThrowsError(try ServerID(validating: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
    }

    func testManagedPathRejectsTraversalAndAbsoluteComponents() {
        XCTAssertThrowsError(try ManagedPath(components: ["servers", "..", "metadata.json"]))
        XCTAssertThrowsError(try ManagedPath(components: ["/Users", "someone"]))
    }

    func testJSONValueRoundTripsNestedUnknownData() throws {
        var fields: [String: JSONValue] = [:]
        fields["future"] = .array([.boolean(true), .integer(42), .null])
        fields["nested"] = .object(["name": .string("kept")])
        let value = JSONValue.object(fields)

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    func testServerIndexRejectsDuplicateIDs() throws {
        let id = try ServerID(validating: "550e8400-e29b-41d4-a716-446655440000")
        let index = ServerIndex(entries: [ServerIndexEntry(id: id), ServerIndexEntry(id: id)])

        XCTAssertThrowsError(try index.validate())
    }

    func testRuntimeConfigurationRejectsInvalidMemoryAndJarPath() throws {
        let java = JavaSelection.systemDefault
        let jvmArguments = JVMArguments(raw: "-Xmx1G", validatedTokens: ["-Xmx1G"], validation: .valid)

        XCTAssertThrowsError(
            try RuntimeConfiguration(
                memoryMiB: 128,
                jarFileName: "server.jar",
                javaSelection: java,
                jvmArguments: jvmArguments,
                eulaAccepted: false
            )
        )
        XCTAssertThrowsError(
            try RuntimeConfiguration(
                memoryMiB: 1024,
                jarFileName: "../server.jar",
                javaSelection: java,
                jvmArguments: jvmArguments,
                eulaAccepted: false
            )
        )
    }

    func testServerMetadataValidatesNestedSections() throws {
        let id = try ServerID(validating: "550e8400-e29b-41d4-a716-446655440000")
        let identity = try ServerIdentity(id: id, displayName: "Test Server")
        let configuration = try RuntimeConfiguration(
            memoryMiB: 4096,
            jarFileName: "server.jar",
            javaSelection: .systemDefault,
            jvmArguments: JVMArguments(raw: "", validation: .valid),
            eulaAccepted: true
        )
        let policies = ServerPolicies(
            crashRecovery: try CrashRecoveryPolicy(mode: .prompt),
            backup: try BackupPolicy(schedule: .disabled, retentionCount: 3),
            notifications: NotificationPolicy(enabled: true, highCPUAlertsEnabled: true)
        )
        let metadata = ServerMetadata(
            identity: identity,
            runtimeConfiguration: configuration,
            policies: policies,
            provenance: Provenance(source: .userCreated, verification: .verified),
            timestamps: MetadataTimestamps(
                registeredAt: Date(timeIntervalSince1970: 1),
                configurationChangedAt: Date(timeIntervalSince1970: 2)
            )
        )

        XCTAssertNoThrow(try metadata.validate())
    }

    func testSecretValueNeverExposesContentsInDescriptions() {
        let secret = SecretValue(data: Data("sensitive-token".utf8))

        XCTAssertEqual(secret.description, "<redacted>")
        XCTAssertEqual(secret.debugDescription, "<redacted>")
        XCTAssertFalse(String(reflecting: secret).contains("sensitive-token"))
    }
}

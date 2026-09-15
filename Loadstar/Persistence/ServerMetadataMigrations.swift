import LoadStarDomain

/// Phase 3 migrations are opt-in so generic persistence tests and other document
/// types keep their existing migration graph.
public enum ServerMetadataMigrations {
    public static func coordinator() -> MigrationCoordinator {
        MigrationCoordinator(steps: [ServerMetadataV1ToV2Migration()])
    }
}

public struct ServerMetadataV1ToV2Migration: MigrationStep {
    public let documentType = DocumentType.serverMetadata
    public let fromRevision = 1
    public let toRevision = 2

    public init() {}

    public func migrate(_ input: JSONValue) throws -> JSONValue {
        guard case .object(var fields) = input else {
            throw DomainValidationError.invalidJSONValue
        }

        guard case .object(var configuration) = fields["runtimeConfiguration"] else {
            throw DomainValidationError.invalidRuntimeIdentity
        }

        if configuration["serverPort"] == nil {
            configuration["serverPort"] = .integer(25_565)
        }
        if configuration["runtimeIdentity"] == nil {
            configuration["runtimeIdentity"] = .object([
                "software": .object(["kind": .string("unknown"), "rawValue": .string("unknown")]),
                "minecraftVersion": .string("unknown"),
                "loader": .null,
            ])
        }
        if configuration["jarArtifact"] == nil {
            configuration["jarArtifact"] = .null
        }
        if configuration["javaVerification"] == nil {
            configuration["javaVerification"] = .null
        }

        fields["runtimeConfiguration"] = .object(configuration)
        fields["schemaVersion"] = .integer(2)
        return .object(fields)
    }
}

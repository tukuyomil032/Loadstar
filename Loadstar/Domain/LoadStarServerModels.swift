import Foundation

public struct ServerIndexEntry: Codable, Equatable, Sendable {
    public let id: ServerID

    public init(id: ServerID) {
        self.id = id
    }
}

public struct ServerIndex: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    public static let documentType = DocumentType.serverIndex
    public static let currentSchemaRevision = 1

    public var entries: [ServerIndexEntry]

    public init(entries: [ServerIndexEntry] = []) {
        self.entries = entries
    }

    public func validate() throws {
        var seen = Set<ServerID>()
        for entry in entries where !seen.insert(entry.id).inserted {
            throw DomainValidationError.duplicateServerID(entry.id)
        }
    }
}

public struct ServerIdentity: Codable, Equatable, Sendable {
    public let id: ServerID
    public var displayName: String
    public var group: String?

    public init(id: ServerID, displayName: String, group: String? = nil) throws {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.invalidDisplayName
        }

        self.id = id
        self.displayName = displayName
        self.group = group
    }

    public func validate() throws {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.invalidDisplayName
        }
    }
}

public enum JavaSelection: Codable, Equatable, Sendable {
    case systemDefault
    case managed(identifier: String)
    case custom(relativeExecutable: ManagedPath)

    private enum CodingKeys: String, CodingKey {
        case kind
        case identifier
        case relativeExecutable
    }

    private enum Kind: String, Codable {
        case systemDefault
        case managed
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .systemDefault:
            self = .systemDefault
        case .managed:
            let identifier = try container.decode(String.self, forKey: .identifier)
            guard !identifier.isEmpty else {
                throw DomainValidationError.invalidPolicy
            }
            self = .managed(identifier: identifier)
        case .custom:
            self = .custom(relativeExecutable: try container.decode(ManagedPath.self, forKey: .relativeExecutable))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .systemDefault:
            try container.encode(Kind.systemDefault, forKey: .kind)
        case .managed(let identifier):
            guard !identifier.isEmpty else {
                throw DomainValidationError.invalidPolicy
            }
            try container.encode(Kind.managed, forKey: .kind)
            try container.encode(identifier, forKey: .identifier)
        case .custom(let relativeExecutable):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(relativeExecutable, forKey: .relativeExecutable)
        }
    }
}

public enum JVMArgumentValidation: String, Codable, Equatable, Sendable {
    case unvalidated
    case valid
    case invalid
}

public enum RuntimeSoftware: Equatable, Sendable, Codable {
    case vanilla
    case paper
    case fabric
    case forge
    case neoforge
    case unknown(rawValue: String)

    private enum CodingKeys: String, CodingKey { case kind, rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "vanilla": self = .vanilla
        case "paper": self = .paper
        case "fabric": self = .fabric
        case "forge": self = .forge
        case "neoforge": self = .neoforge
        case "unknown":
            let rawValue = try container.decodeIfPresent(String.self, forKey: .rawValue) ?? "unknown"
            guard !rawValue.isEmpty else { throw DomainValidationError.invalidRuntimeIdentity }
            self = .unknown(rawValue: rawValue)
        default:
            self = .unknown(rawValue: kind)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vanilla: try container.encode("vanilla", forKey: .kind)
        case .paper: try container.encode("paper", forKey: .kind)
        case .fabric: try container.encode("fabric", forKey: .kind)
        case .forge: try container.encode("forge", forKey: .kind)
        case .neoforge: try container.encode("neoforge", forKey: .kind)
        case .unknown(let rawValue):
            guard !rawValue.isEmpty else { throw DomainValidationError.invalidRuntimeIdentity }
            try container.encode("unknown", forKey: .kind)
            try container.encode(rawValue, forKey: .rawValue)
        }
    }
}

public struct RuntimeIdentity: Codable, Equatable, Sendable {
    public var software: RuntimeSoftware
    public var minecraftVersion: String
    public var loader: String?

    public init(
        software: RuntimeSoftware,
        minecraftVersion: String,
        loader: String? = nil
    ) {
        self.software = software
        self.minecraftVersion = minecraftVersion
        self.loader = loader
    }

    public static let unknown = Self(software: .unknown(rawValue: "unknown"), minecraftVersion: "unknown")

    public func validate() throws {
        guard !minecraftVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.invalidRuntimeIdentity
        }
        if let loader, loader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DomainValidationError.invalidRuntimeIdentity
        }
    }
}

public struct JavaVerification: Codable, Equatable, Sendable {
    public let majorVersion: Int?
    public let vendor: String?
    public let verification: VerificationState
    public let verifiedAt: Date?

    public init(
        majorVersion: Int?,
        vendor: String?,
        verification: VerificationState,
        verifiedAt: Date?
    ) {
        self.majorVersion = majorVersion
        self.vendor = vendor
        self.verification = verification
        self.verifiedAt = verifiedAt
    }

    public func validate() throws {
        if let majorVersion, majorVersion < 1 {
            throw DomainValidationError.invalidJavaVerification
        }
    }
}

public struct JVMArguments: Codable, Equatable, Sendable {
    public let raw: String
    public let validatedTokens: [String]
    public let validation: JVMArgumentValidation

    public init(
        raw: String,
        validatedTokens: [String] = [],
        validation: JVMArgumentValidation = .unvalidated
    ) {
        self.raw = raw
        self.validatedTokens = validatedTokens
        self.validation = validation
    }
}

public struct RuntimeConfiguration: Codable, Equatable, Sendable {
    public var memoryMiB: Int
    public var jarFileName: String
    public var javaSelection: JavaSelection
    public var jvmArguments: JVMArguments
    public var eulaAccepted: Bool
    public var serverPort: Int
    public var runtimeIdentity: RuntimeIdentity
    public var jarArtifact: ArtifactIdentity?
    public var javaVerification: JavaVerification?

    private enum CodingKeys: String, CodingKey {
        case memoryMiB
        case jarFileName
        case javaSelection
        case jvmArguments
        case eulaAccepted
        case serverPort
        case runtimeIdentity
        case jarArtifact
        case javaVerification
    }

    public init(
        memoryMiB: Int,
        jarFileName: String,
        javaSelection: JavaSelection,
        jvmArguments: JVMArguments,
        eulaAccepted: Bool,
        serverPort: Int = 25_565,
        runtimeIdentity: RuntimeIdentity = .unknown,
        jarArtifact: ArtifactIdentity? = nil,
        javaVerification: JavaVerification? = nil
    ) throws {
        guard (256...65_536).contains(memoryMiB) else {
            throw DomainValidationError.invalidMemoryMiB(memoryMiB)
        }
        guard Self.isSafeJarFileName(jarFileName) else {
            throw DomainValidationError.invalidJarFileName(jarFileName)
        }
        guard (1...65_535).contains(serverPort) else {
            throw DomainValidationError.invalidServerPort(serverPort)
        }
        try runtimeIdentity.validate()
        try javaVerification?.validate()

        self.memoryMiB = memoryMiB
        self.jarFileName = jarFileName
        self.javaSelection = javaSelection
        self.jvmArguments = jvmArguments
        self.eulaAccepted = eulaAccepted
        self.serverPort = serverPort
        self.runtimeIdentity = runtimeIdentity
        self.jarArtifact = jarArtifact
        self.javaVerification = javaVerification
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            memoryMiB: try container.decode(Int.self, forKey: .memoryMiB),
            jarFileName: try container.decode(String.self, forKey: .jarFileName),
            javaSelection: try container.decode(JavaSelection.self, forKey: .javaSelection),
            jvmArguments: try container.decode(JVMArguments.self, forKey: .jvmArguments),
            eulaAccepted: try container.decode(Bool.self, forKey: .eulaAccepted),
            serverPort: try container.decodeIfPresent(Int.self, forKey: .serverPort) ?? 25_565,
            runtimeIdentity: try container.decodeIfPresent(RuntimeIdentity.self, forKey: .runtimeIdentity) ?? .unknown,
            jarArtifact: try container.decodeIfPresent(ArtifactIdentity.self, forKey: .jarArtifact),
            javaVerification: try container.decodeIfPresent(JavaVerification.self, forKey: .javaVerification)
        )
    }

    public func validate() throws {
        guard (256...65_536).contains(memoryMiB) else {
            throw DomainValidationError.invalidMemoryMiB(memoryMiB)
        }
        guard Self.isSafeJarFileName(jarFileName) else {
            throw DomainValidationError.invalidJarFileName(jarFileName)
        }
        guard (1...65_535).contains(serverPort) else {
            throw DomainValidationError.invalidServerPort(serverPort)
        }
        try runtimeIdentity.validate()
        try javaVerification?.validate()
    }

    private static func isSafeJarFileName(_ value: String) -> Bool {
        !value.isEmpty && value.hasSuffix(".jar") && !value.contains("/") && !value.contains("\\") && value != "."
            && value != ".."
    }
}

public enum ProvenanceSource: String, Codable, Equatable, Sendable {
    case userCreated
    case detected
    case imported
    case generated
}

public enum VerificationState: String, Codable, Equatable, Sendable {
    case unverified
    case verified
    case stale
    case failed
}

public struct Provenance: Codable, Equatable, Sendable {
    public let source: ProvenanceSource
    public let observedAt: Date?
    public let verifiedAt: Date?
    public let verification: VerificationState
    public let safeSourceReference: String?

    public init(
        source: ProvenanceSource,
        observedAt: Date? = nil,
        verifiedAt: Date? = nil,
        verification: VerificationState,
        safeSourceReference: String? = nil
    ) {
        self.source = source
        self.observedAt = observedAt
        self.verifiedAt = verifiedAt
        self.verification = verification
        self.safeSourceReference = safeSourceReference
    }
}

public struct MetadataTimestamps: Codable, Equatable, Sendable {
    public let registeredAt: Date
    public var configurationChangedAt: Date
    public var lastVerifiedAt: Date?

    public init(
        registeredAt: Date,
        configurationChangedAt: Date,
        lastVerifiedAt: Date? = nil
    ) {
        self.registeredAt = registeredAt
        self.configurationChangedAt = configurationChangedAt
        self.lastVerifiedAt = lastVerifiedAt
    }
}

public struct ServerMetadata: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    public static let documentType = DocumentType.serverMetadata
    public static let currentSchemaRevision = 2

    public var identity: ServerIdentity
    public var runtimeConfiguration: RuntimeConfiguration
    public var policies: ServerPolicies
    public var provenance: Provenance
    public var timestamps: MetadataTimestamps
    public var profileTemplateID: String?

    public init(
        identity: ServerIdentity,
        runtimeConfiguration: RuntimeConfiguration,
        policies: ServerPolicies,
        provenance: Provenance,
        timestamps: MetadataTimestamps,
        profileTemplateID: String? = nil
    ) {
        self.identity = identity
        self.runtimeConfiguration = runtimeConfiguration
        self.policies = policies
        self.provenance = provenance
        self.timestamps = timestamps
        self.profileTemplateID = profileTemplateID
    }

    public func validate() throws {
        try identity.validate()
        try runtimeConfiguration.validate()
        try policies.validate()
    }
}

public struct ProfileTemplate: Codable, Equatable, Sendable {
    public let identifier: String
    public var displayName: String
    public var runtimeConfiguration: RuntimeConfiguration
    public var policies: ServerPolicies

    public init(
        identifier: String,
        displayName: String,
        runtimeConfiguration: RuntimeConfiguration,
        policies: ServerPolicies
    ) throws {
        guard !identifier.isEmpty, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.invalidPolicy
        }

        self.identifier = identifier
        self.displayName = displayName
        self.runtimeConfiguration = runtimeConfiguration
        self.policies = policies
    }
}

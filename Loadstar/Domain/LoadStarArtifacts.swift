import Foundation

public enum ArtifactKind: String, Codable, Equatable, Sendable {
    case serverJar
    case plugin
    case mod
    case proxy
    case forwardingMod
    case unknown
}

public enum ArtifactSource: Codable, Equatable, Sendable {
    case official
    case provider(name: String)
    case imported
    case generated

    private enum CodingKeys: String, CodingKey {
        case kind
        case name
    }

    private enum Kind: String, Codable {
        case official
        case provider
        case imported
        case generated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .official:
            self = .official
        case .provider:
            self = .provider(name: try container.decode(String.self, forKey: .name))
        case .imported:
            self = .imported
        case .generated:
            self = .generated
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .official:
            try container.encode(Kind.official, forKey: .kind)
        case .provider(let name):
            try container.encode(Kind.provider, forKey: .kind)
            try container.encode(name, forKey: .name)
        case .imported:
            try container.encode(Kind.imported, forKey: .kind)
        case .generated:
            try container.encode(Kind.generated, forKey: .kind)
        }
    }
}

public struct SHA256Digest: Codable, Equatable, Hashable, Sendable {
    public let hex: String

    public init(validating hex: String) throws {
        let normalized = hex.lowercased()
        guard normalized.count == 64,
            normalized.unicodeScalars.allSatisfy({
                $0.value >= 48 && $0.value <= 57 || $0.value >= 97 && $0.value <= 102
            })
        else {
            throw DomainValidationError.invalidChecksum(hex)
        }

        self.hex = normalized
    }
}

public struct ArtifactIdentity: Codable, Equatable, Sendable {
    public let kind: ArtifactKind
    public let source: ArtifactSource
    public let filename: String
    public let version: String?
    public let loader: String?
    public let gameVersion: String?
    public let checksum: SHA256Digest
    public let dependencies: [String]
    public let provenance: Provenance

    public init(
        kind: ArtifactKind,
        source: ArtifactSource,
        filename: String,
        version: String?,
        loader: String?,
        gameVersion: String?,
        checksum: SHA256Digest,
        dependencies: [String] = [],
        provenance: Provenance
    ) {
        self.kind = kind
        self.source = source
        self.filename = filename
        self.version = version
        self.loader = loader
        self.gameVersion = gameVersion
        self.checksum = checksum
        self.dependencies = dependencies
        self.provenance = provenance
    }

    public func validate() throws {
        guard !filename.isEmpty,
            filename != ".",
            filename != "..",
            !filename.contains("/"),
            !filename.contains("\\")
        else {
            throw DomainValidationError.invalidArtifactIdentity
        }

        _ = try SHA256Digest(validating: checksum.hex)
        if case .provider(let name) = source, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DomainValidationError.invalidArtifactIdentity
        }
    }
}

public struct BackupDescriptor: Codable, Equatable, Sendable {
    public let id: OperationID
    public let serverID: ServerID
    public let createdAt: Date
    public let archivePath: ManagedPath
    public let size: Int64
    public let checksum: SHA256Digest
    public let manifestVersion: Int

    public init(
        id: OperationID,
        serverID: ServerID,
        createdAt: Date,
        archivePath: ManagedPath,
        size: Int64,
        checksum: SHA256Digest,
        manifestVersion: Int
    ) throws {
        guard size >= 0, manifestVersion > 0 else {
            throw DomainValidationError.invalidPolicy
        }

        self.id = id
        self.serverID = serverID
        self.createdAt = createdAt
        self.archivePath = archivePath
        self.size = size
        self.checksum = checksum
        self.manifestVersion = manifestVersion
    }
}

public struct BackupCatalog: Codable, Equatable, Sendable, LoadStarDocumentPayload {
    public static let documentType = DocumentType.backupCatalog
    public static let currentSchemaRevision = 1

    public var entries: [BackupDescriptor]

    public init(entries: [BackupDescriptor] = []) {
        self.entries = entries
    }

    public func validate() throws {
        var seen = Set<OperationID>()
        for entry in entries where !seen.insert(entry.id).inserted {
            throw DomainValidationError.invalidPolicy
        }
    }
}

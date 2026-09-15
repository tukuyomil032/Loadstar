import Foundation
import LoadStarDomain

public enum QuarantineStoreError: Error, Sendable {
    case recordWriteFailed(ManagedPath, String)
}

public struct QuarantineStore: Sendable {
    private let fileSystem: any FileSystemClient
    private let clock: any Clock

    public init(fileSystem: any FileSystemClient, clock: any Clock = SystemClock()) {
        self.fileSystem = fileSystem
        self.clock = clock
    }

    public func quarantine(
        path: ManagedPath,
        header: DocumentHeader?,
        documentType: DocumentType,
        issueCode: String
    ) async throws -> QuarantineRecord {
        let quarantineID = OperationID.new()
        let quarantinePath = try ManagedPath(components: [
            "quarantine",
            "documents",
            "(documentType.rawValue)-(quarantineID.rawValue).json",
        ])
        if let parent = quarantinePath.parent {
            try await fileSystem.createDirectory(at: parent)
        }
        try await fileSystem.moveItem(at: path, to: quarantinePath)

        let record = QuarantineRecord(
            id: quarantineID,
            documentType: header?.documentType,
            detectedRevision: header?.revision,
            path: quarantinePath,
            issueCode: issueCode,
            detectedAt: clock.now()
        )
        let recordPath = try ManagedPath(components: [
            "quarantine",
            "records",
            "(quarantineID.rawValue).json",
        ])
        do {
            if let parent = recordPath.parent {
                try await fileSystem.createDirectory(at: parent)
            }
            try await fileSystem.writeData(try Self.encode(record), at: recordPath)
            try await fileSystem.synchronize(at: recordPath)
        } catch {
            throw QuarantineStoreError.recordWriteFailed(recordPath, String(describing: error))
        }
        return record
    }

    public func migrationCandidates() async throws -> [ManagedPath] {
        let directory = try ManagedPath(components: ["quarantine", "migration-backups"])
        guard try await fileSystem.exists(at: directory) else {
            return []
        }
        return try await fileSystem.listDirectory(at: directory).sorted { $0.relativePath < $1.relativePath }
    }

    private static func encode(_ record: QuarantineRecord) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(record)
    }
}

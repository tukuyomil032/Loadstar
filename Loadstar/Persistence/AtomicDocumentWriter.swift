import Foundation
import LoadStarDomain

struct AtomicWriteResult<Value: Sendable>: Sendable {
    let value: Value
    let cleanupResult: String?
}

struct AtomicWriteFailure: Error, Sendable {
    let stage: FailureStage
    let target: ManagedPath
    let temporaryPath: ManagedPath?
    let cleanupResult: String?
    let detail: String
}

struct AtomicDocumentWriter: Sendable {
    let fileSystem: any FileSystemClient
    let codec: DocumentCodec

    func write<Payload: LoadStarDocumentPayload>(
        data: Data,
        document: LoadStarDocument<Payload>,
        at destination: ManagedPath
    ) async throws -> AtomicWriteResult<Payload> {
        guard let parent = destination.parent, let filename = destination.components.last else {
            throw AtomicWriteFailure(
                stage: .pathValidation,
                target: destination,
                temporaryPath: nil,
                cleanupResult: nil,
                detail: "The destination must include a parent directory and filename."
            )
        }

        let temporaryPath = try parent.appending(".\(filename).\(OperationID.new().rawValue).tmp")
        var stage: FailureStage = .write

        do {
            try await fileSystem.createDirectory(at: parent)
            try await fileSystem.writeData(data, at: temporaryPath)
            stage = .synchronize
            try await fileSystem.synchronize(at: temporaryPath)

            stage = .validation
            let readBack = try await fileSystem.readData(at: temporaryPath)
            let decoded = try codec.decode(Payload.self, from: readBack, expectedDocumentType: document.documentType)
            try decoded.payload.validate()

            stage = .replace
            try await fileSystem.replaceItem(at: destination, with: temporaryPath)
            let cleanupResult = await cleanup(temporaryPath)
            return AtomicWriteResult(value: decoded.payload, cleanupResult: cleanupResult)
        } catch let failure as AtomicWriteFailure {
            throw failure
        } catch {
            let cleanupResult = await cleanup(temporaryPath)
            throw AtomicWriteFailure(
                stage: stage,
                target: destination,
                temporaryPath: temporaryPath,
                cleanupResult: cleanupResult,
                detail: String(describing: error)
            )
        }
    }

    private func cleanup(_ path: ManagedPath) async -> String? {
        do {
            guard try await fileSystem.exists(at: path) else {
                return nil
            }
            try await fileSystem.removeItem(at: path)
            return nil
        } catch {
            return "Temporary artifact retained at \(path.relativePath); cleanup can be retried."
        }
    }
}

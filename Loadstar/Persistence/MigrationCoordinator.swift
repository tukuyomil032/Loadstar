import LoadStarDomain

public enum MigrationCoordinatorError: Error, Equatable, Sendable {
    case noStep(fromRevision: Int, targetRevision: Int)
    case invalidStep(fromRevision: Int, toRevision: Int)
    case invalidOutput(expectedRevision: Int)
    case cycleDetected
}

public protocol MigrationStep: Sendable {
    var documentType: DocumentType { get }
    var fromRevision: Int { get }
    var toRevision: Int { get }

    func migrate(_ input: JSONValue) throws -> JSONValue
}

public struct MigrationCoordinator: Sendable {
    private let steps: [any MigrationStep]

    public init(steps: [any MigrationStep] = []) {
        self.steps = steps
    }

    public func migrate(
        _ input: JSONValue,
        documentType: DocumentType,
        fromRevision: Int,
        toRevision: Int
    ) throws -> JSONValue {
        guard fromRevision <= toRevision else {
            throw MigrationCoordinatorError.invalidStep(fromRevision: fromRevision, toRevision: toRevision)
        }

        var currentRevision = fromRevision
        var currentValue = input
        var visited = Set<Int>()

        while currentRevision < toRevision {
            guard visited.insert(currentRevision).inserted else {
                throw MigrationCoordinatorError.cycleDetected
            }

            guard
                let step = steps.first(where: {
                    $0.documentType == documentType && $0.fromRevision == currentRevision
                })
            else {
                throw MigrationCoordinatorError.noStep(fromRevision: currentRevision, targetRevision: toRevision)
            }

            guard step.toRevision > step.fromRevision, step.toRevision <= toRevision else {
                throw MigrationCoordinatorError.invalidStep(
                    fromRevision: step.fromRevision,
                    toRevision: step.toRevision
                )
            }

            currentValue = try step.migrate(currentValue)
            let outputHeader: DocumentHeader
            do {
                let outputData = try DocumentCodec().encodeRaw(currentValue)
                outputHeader = try DocumentCodec().decodeHeader(from: outputData)
            } catch {
                throw MigrationCoordinatorError.invalidOutput(expectedRevision: step.toRevision)
            }
            guard outputHeader.documentType == documentType, outputHeader.revision == step.toRevision else {
                throw MigrationCoordinatorError.invalidOutput(expectedRevision: step.toRevision)
            }
            currentRevision = step.toRevision
        }

        return currentValue
    }
}

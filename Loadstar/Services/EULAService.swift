import Foundation
import LoadStarDomain
import LoadStarPlatform

public enum EULAServiceError: Error, Equatable, Sendable {
    case automaticConsentForbidden
    case writeFailed
}

public struct BundledEULAText: Equatable, Sendable {
    public let english: String
    public let japaneseReference: String
    public let officialURL: URL
    public let checkedDate: String

    public init(english: String, japaneseReference: String, officialURL: URL, checkedDate: String) {
        self.english = english
        self.japaneseReference = japaneseReference
        self.officialURL = officialURL
        self.checkedDate = checkedDate
    }
}

public protocol EULAService: Sendable {
    func state(for serverDirectory: ManagedPath) async -> EULAState
    func accept(for serverDirectory: ManagedPath, intent: LaunchIntent) async throws -> EULAState
    func bundledText() -> BundledEULAText
}

public struct FileEULAService: EULAService {
    private let fileSystem: any FileSystemClient

    public init(fileSystem: any FileSystemClient) {
        self.fileSystem = fileSystem
    }

    public func state(for serverDirectory: ManagedPath) async -> EULAState {
        do {
            let path = try serverDirectory.appending("eula.txt")
            let data = try await fileSystem.readData(at: path)
            let contents = String(decoding: data, as: UTF8.self)
            let value =
                contents
                .split(whereSeparator: \.isNewline)
                .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("eula=") })
                .map { $0.split(separator: "=", maxSplits: 1).last?.lowercased() }
            switch value {
            case "true": return .accepted
            case "false": return .declined
            default:
                return .unreadable(
                    LifecycleIssue(
                        code: "server.eula.unreadable",
                        message: "The eula.txt value could not be understood.",
                        recoveryAction: .manualRepair
                    ))
            }
        } catch let error as FileSystemError {
            if case .notFound = error {
                return .required
            }
            return .unreadable(
                LifecycleIssue(
                    code: "server.eula.readFailed",
                    message: "The EULA file could not be read.",
                    retryability: .retryable,
                    recoveryAction: .retry
                ))
        } catch {
            return .unreadable(
                LifecycleIssue(
                    code: "server.eula.readFailed",
                    message: "The EULA file could not be read.",
                    retryability: .retryable,
                    recoveryAction: .retry
                ))
        }
    }

    public func accept(for serverDirectory: ManagedPath, intent: LaunchIntent) async throws -> EULAState {
        guard intent == .manual else { throw EULAServiceError.automaticConsentForbidden }
        do {
            let path = try serverDirectory.appending("eula.txt")
            try await fileSystem.writeData(
                Data("# Generated after explicit user consent\neula=true\n".utf8),
                at: path
            )
            return .accepted
        } catch {
            throw EULAServiceError.writeFailed
        }
    }

    public func bundledText() -> BundledEULAText {
        let english = loadResource(named: "eula.en")
        let japanese = loadResource(named: "eula.ja")
        return BundledEULAText(
            english: english,
            japaneseReference: japanese,
            officialURL: URL(string: "https://www.minecraft.net/en-us/eula")!,
            checkedDate: "2026-09-15"
        )
    }

    private func loadResource(named name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "EULA"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "The official Minecraft EULA is available at https://www.minecraft.net/en-us/eula."
        }
        return text
    }
}

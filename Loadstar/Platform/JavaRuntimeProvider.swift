import Foundation
import LoadStarDomain

public enum JavaRuntimeError: Error, Equatable, Sendable {
    case discoveryFailed(String)
    case noSystemDefault
    case installationMissing(String)
    case customJavaRequiresOneShotOverride
    case executableInvalid(String)
    case versionMismatch(requiredMajor: Int, actualMajor: Int?)
}

public protocol JavaRuntimeProvider: Sendable {
    func discover() async throws -> [JavaInstallation]
    func resolve(selection: JavaSelection, override: LaunchJavaOverride?) async throws -> JavaResolution
}

public struct MacOSJavaRuntimeProvider: JavaRuntimeProvider {
    private let fixedInstallations: [JavaInstallation]?
    private let requiredMajorVersion: Int?
    private let validator: JavaExecutableValidator

    public init(
        installations: [JavaInstallation]? = nil,
        requiredMajorVersion: Int? = nil,
        validator: JavaExecutableValidator = JavaExecutableValidator()
    ) {
        self.fixedInstallations = installations
        self.requiredMajorVersion = requiredMajorVersion
        self.validator = validator
    }

    public func discover() async throws -> [JavaInstallation] {
        if let fixedInstallations {
            return fixedInstallations
        }
        return try await Self.discoverWithJavaHome()
    }

    public func resolve(selection: JavaSelection, override: LaunchJavaOverride? = nil) async throws -> JavaResolution {
        if let override {
            let verification = try validator.validate(executableURL: override.executableURL)
            return try makeResolution(
                executableURL: override.executableURL,
                installationID: nil,
                verification: verification
            )
        }

        switch selection {
        case .custom:
            throw JavaRuntimeError.customJavaRequiresOneShotOverride
        case .systemDefault:
            let installations = try await discover()
            guard let installation = installations.sorted(by: Self.preferredOrder).first else {
                throw JavaRuntimeError.noSystemDefault
            }
            let verification = try validator.validate(executableURL: installation.executableURL)
            return try makeResolution(
                executableURL: installation.executableURL,
                installationID: installation.identifier,
                verification: verification
            )
        case .managed(let identifier):
            guard let installation = try await discover().first(where: { $0.identifier == identifier }) else {
                throw JavaRuntimeError.installationMissing(identifier)
            }
            let verification = try validator.validate(executableURL: installation.executableURL)
            return try makeResolution(
                executableURL: installation.executableURL,
                installationID: installation.identifier,
                verification: verification
            )
        }
    }

    private func makeResolution(
        executableURL: URL,
        installationID: String?,
        verification: JavaVerification
    ) throws -> JavaResolution {
        let compatibility: JavaCompatibility
        if let requiredMajorVersion {
            guard let actualMajor = verification.majorVersion else {
                compatibility = .unknown
                return JavaResolution(
                    executableURL: executableURL,
                    installationID: installationID,
                    majorVersion: verification.majorVersion,
                    vendor: verification.vendor,
                    compatibility: compatibility
                )
            }
            if actualMajor == requiredMajorVersion {
                compatibility = .compatible
            } else {
                compatibility = .mismatch(requiredMajor: requiredMajorVersion, actualMajor: actualMajor)
            }
        } else {
            compatibility = .unknown
        }
        return JavaResolution(
            executableURL: executableURL,
            installationID: installationID,
            majorVersion: verification.majorVersion,
            vendor: verification.vendor,
            compatibility: compatibility
        )
    }

    private static func preferredOrder(_ lhs: JavaInstallation, _ rhs: JavaInstallation) -> Bool {
        switch (lhs.majorVersion, rhs.majorVersion) {
        case (let left?, let right?) where left != right: return left > right
        default: return lhs.identifier < rhs.identifier
        }
    }

    private static func discoverWithJavaHome() async throws -> [JavaInstallation] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        process.arguments = ["-V"]
        process.standardOutput = output
        process.standardError = output

        do {
            try process.run()
        } catch {
            throw JavaRuntimeError.discoveryFailed("java.discovery.commandUnavailable")
        }
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 || !text.isEmpty else {
            throw JavaRuntimeError.discoveryFailed("java.discovery.commandFailed")
        }
        let installations = parseJavaHomeOutput(text)
        guard !installations.isEmpty else {
            throw JavaRuntimeError.noSystemDefault
        }
        return installations
    }

    public static func parseJavaHomeOutput(_ output: String) -> [JavaInstallation] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let pathStart = line.firstIndex(of: "/") else { return nil }
            let path = String(line[pathStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let url = URL(fileURLWithPath: path)
            let identifier =
                url.deletingLastPathComponent().lastPathComponent.isEmpty
                ? path
                : url.deletingLastPathComponent().lastPathComponent
            let major = JavaExecutableValidator.parseMajorVersion(from: line)
            return JavaInstallation(
                identifier: identifier,
                executableURL: url.appendingPathComponent("bin/java"),
                homeURL: url,
                majorVersion: major,
                vendor: nil
            )
        }
    }
}

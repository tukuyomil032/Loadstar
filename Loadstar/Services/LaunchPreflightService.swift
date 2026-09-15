import CryptoKit
import Foundation
import LoadStarDomain
import LoadStarPlatform

import struct LoadStarDomain.SHA256Digest

public struct LaunchPreflightReport: Equatable, Sendable {
    public let result: LaunchPreflight
    public let javaResolution: JavaResolution?
    public let validatedJVMArguments: [String]
    public let jarDigest: SHA256Digest?

    public init(
        result: LaunchPreflight,
        javaResolution: JavaResolution? = nil,
        validatedJVMArguments: [String] = [],
        jarDigest: SHA256Digest? = nil
    ) {
        self.result = result
        self.javaResolution = javaResolution
        self.validatedJVMArguments = validatedJVMArguments
        self.jarDigest = jarDigest
    }
}

public struct LaunchPreflightService: Sendable {
    private let javaProvider: any JavaRuntimeProvider
    private let fileSystem: any FileSystemClient
    private let eulaService: any EULAService
    private let serverDirectory: ManagedPath

    public init(
        javaProvider: any JavaRuntimeProvider,
        fileSystem: any FileSystemClient,
        eulaService: any EULAService,
        serverDirectory: ManagedPath
    ) {
        self.javaProvider = javaProvider
        self.fileSystem = fileSystem
        self.eulaService = eulaService
        self.serverDirectory = serverDirectory
    }

    public func evaluate(
        metadata: ServerMetadata,
        intent: LaunchIntent,
        customJava: LaunchJavaOverride? = nil
    ) async -> LaunchPreflightReport {
        let configuration = metadata.runtimeConfiguration

        guard (1...65_535).contains(configuration.serverPort) else {
            return blocked("server.start.port.invalid", "The configured server port is invalid.")
        }

        let arguments: [String]
        do {
            arguments = try JVMArgumentParser().parse(
                configuration.jvmArguments.raw,
                storedTokens: configuration.jvmArguments.validatedTokens.isEmpty
                    ? nil
                    : configuration.jvmArguments.validatedTokens
            )
        } catch {
            return blocked("java.jvmArguments.invalid", "The JVM arguments must be repaired before launch.")
        }

        let javaResolution: JavaResolution
        do {
            javaResolution = try await javaProvider.resolve(
                selection: configuration.javaSelection,
                override: customJava
            )
        } catch let error as JavaRuntimeError {
            return blocked(javaCode(for: error), "Java could not be resolved for this launch.")
        } catch {
            return blocked("java.resolve.failed", "Java could not be resolved for this launch.")
        }

        if case .mismatch(let requiredMajor, let actualMajor) = javaResolution.compatibility {
            let actual = actualMajor.map(String.init) ?? "unknown"
            let message = "Java \(actual) does not match required major \(requiredMajor)."
            if intent == .manual {
                return LaunchPreflightReport(
                    result: .needsUserConfirmation(
                        ConfirmationRequirement(code: "java.compatibility.mismatch", message: message, intent: intent)),
                    javaResolution: javaResolution,
                    validatedJVMArguments: arguments
                )
            }
            return blocked("java.compatibility.mismatch", "Automatic launch cannot approve a Java version mismatch.")
        }

        let jarPath: ManagedPath
        do {
            jarPath = try serverDirectory.appending(configuration.jarFileName)
            let metadata = try await fileSystem.metadata(at: jarPath)
            guard !metadata.isDirectory, !metadata.isSymbolicLink else {
                return blocked("server.start.jar.invalidFile", "The server JAR must be a regular file.")
            }
            let data = try await fileSystem.readData(at: jarPath)
            let digest = try SHA256Digest(
                validating: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
            if let expected = configuration.jarArtifact?.checksum, expected != digest {
                return blocked("server.start.jar.checksumMismatch", "The server JAR checksum does not match metadata.")
            }

            let eulaState = await eulaService.state(for: serverDirectory)
            switch eulaState {
            case .accepted:
                return LaunchPreflightReport(
                    result: .ready(warnings: []), javaResolution: javaResolution,
                    validatedJVMArguments: arguments, jarDigest: digest)
            case .required:
                return LaunchPreflightReport(
                    result: .needsUserConfirmation(
                        ConfirmationRequirement(
                            code: "server.eula.required",
                            message: "You must review and explicitly accept the Minecraft EULA before launching.",
                            intent: intent)),
                    javaResolution: javaResolution, validatedJVMArguments: arguments, jarDigest: digest)
            case .declined:
                return blocked("server.eula.declined", "The Minecraft EULA was declined.")
            case .unreadable(let issue):
                return LaunchPreflightReport(
                    result: .blocked(issue), javaResolution: javaResolution,
                    validatedJVMArguments: arguments, jarDigest: digest)
            }
        } catch FileSystemError.notFound {
            return blocked("server.start.jar.missing", "The configured server JAR is missing.")
        } catch {
            return blocked("server.start.jar.unreadable", "The configured server JAR could not be verified.")
        }
    }

    private func blocked(_ code: String, _ message: String) -> LaunchPreflightReport {
        LaunchPreflightReport(result: .blocked(LifecycleIssue(code: code, message: message)))
    }

    private func javaCode(for error: JavaRuntimeError) -> String {
        switch error {
        case .discoveryFailed: return "java.discovery.failed"
        case .noSystemDefault: return "java.systemDefault.missing"
        case .installationMissing: return "java.managed.missing"
        case .customJavaRequiresOneShotOverride: return "java.custom.oneShotRequired"
        case .executableInvalid: return "java.executable.invalid"
        case .versionMismatch: return "java.compatibility.mismatch"
        }
    }
}

import Foundation

public struct JVMArgumentParser: Sendable {
    public static let maximumTokenCount = 32

    public init() {}

    public func parse(_ raw: String, storedTokens: [String]? = nil) throws -> [String] {
        let tokens = raw.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }).map(String.init)
        guard tokens.count <= Self.maximumTokenCount else {
            throw DomainValidationError.invalidJVMArguments("java.jvmArguments.tooManyTokens")
        }
        for token in tokens {
            guard isAllowed(token) else {
                throw DomainValidationError.invalidJVMArguments("java.jvmArguments.tokenRejected")
            }
        }
        if let storedTokens, storedTokens != tokens {
            throw DomainValidationError.invalidJVMArguments("java.jvmArguments.rawTokenMismatch")
        }
        return tokens
    }

    public func validate(_ arguments: JVMArguments) throws -> JVMArguments {
        let tokens = try parse(
            arguments.raw, storedTokens: arguments.validatedTokens.isEmpty ? nil : arguments.validatedTokens)
        return JVMArguments(raw: arguments.raw, validatedTokens: tokens, validation: .valid)
    }

    private func isAllowed(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        let forbiddenCharacters = CharacterSet(charactersIn: ";|&><$()`")
        guard token.unicodeScalars.allSatisfy({ !forbiddenCharacters.contains($0) }) else { return false }

        let deniedPrefixes = [
            "-javaagent:", "-agentlib:", "-agentpath:", "-cp", "-classpath", "--class-path", "-jar",
            "-Djava.security.manager", "-Djava.system.class.loader",
        ]
        guard !deniedPrefixes.contains(where: { token == $0 || token.hasPrefix($0 + "=") || token.hasPrefix($0 + ":") })
        else {
            return false
        }

        let allowedPrefixes = [
            "-Xms", "-Xmx", "-Xss", "-XX:+UseG1GC", "-XX:-UseG1GC", "-XX:+UseStringDeduplication",
            "-XX:MaxGCPauseMillis=", "-XX:MaxRAMPercentage=", "-Dfile.encoding=", "-Duser.language=",
            "-Duser.country=", "-Djava.awt.headless=",
        ]
        return allowedPrefixes.contains(where: { token == $0 || token.hasPrefix($0) })
    }
}

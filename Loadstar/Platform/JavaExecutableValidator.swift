import Foundation
import LoadStarDomain

public struct JavaExecutableValidator: Sendable {
    private let injectedVerification: (@Sendable (URL) throws -> JavaVerification)?

    public init(injectedVerification: (@Sendable (URL) throws -> JavaVerification)? = nil) {
        self.injectedVerification = injectedVerification
    }

    public func validate(executableURL: URL) throws -> JavaVerification {
        if let injectedVerification {
            return try injectedVerification(executableURL)
        }
        var isDirectory: ObjCBool = false
        let path = executableURL.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw JavaRuntimeError.executableInvalid("java.executable.missing")
        }
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw JavaRuntimeError.executableInvalid("java.executable.notExecutable")
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["-version"]
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            throw JavaRuntimeError.executableInvalid("java.executable.cannotLaunch")
        }
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw JavaRuntimeError.executableInvalid("java.executable.versionCheckFailed")
        }
        let parsed = Self.parseVersionOutput(text)
        guard let majorVersion = parsed.majorVersion else {
            throw JavaRuntimeError.executableInvalid("java.executable.versionUnreadable")
        }
        return JavaVerification(
            majorVersion: majorVersion,
            vendor: parsed.vendor,
            verification: .verified,
            verifiedAt: Date()
        )
    }

    public static func parseVersionOutput(_ output: String) -> (majorVersion: Int?, vendor: String?) {
        let firstLine = output.split(whereSeparator: \.isNewline).first.map(String.init) ?? output
        let versionToken =
            firstLine.split(separator: "\"").dropFirst().first.map(String.init)
            ?? firstLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).last.map(String.init)
        let major = versionToken.flatMap(parseMajorVersion)
        let vendor: String?
        if firstLine.localizedCaseInsensitiveContains("openjdk") {
            vendor = "OpenJDK"
        } else if firstLine.localizedCaseInsensitiveContains("oracle") {
            vendor = "Oracle"
        } else {
            vendor = nil
        }
        return (major, vendor)
    }

    public static func parseMajorVersion(from value: String) -> Int? {
        let token = value.split(whereSeparator: { !$0.isNumber && $0 != "." }).first.map(String.init) ?? value
        let components = token.split(separator: ".")
        guard let first = components.first, let number = Int(first) else { return nil }
        return number == 1 && components.count > 1 ? Int(components[1]) : number
    }
}

import Foundation

public enum FixtureSLPMode: String, Codable, Equatable, Sendable {
    case ready
    case malformed
    case failure
}

public struct LoadStarFixtureScenario: Codable, Equatable, Sendable {
    public let startupDelayMillis: Int
    public let readyAfterMillis: Int
    public let slp: FixtureSLPMode
    public let gracefulStopDelayMillis: Int
    public let ignoreTermination: Bool
    public let spawnChild: Bool
    public let crashAfterMillis: Int?
    public let stdout: [String]
    public let stderr: [String]
    public let invalidUTF8: Bool

    public init(
        startupDelayMillis: Int = 0,
        readyAfterMillis: Int = 5_000,
        slp: FixtureSLPMode = .ready,
        gracefulStopDelayMillis: Int = 0,
        ignoreTermination: Bool = false,
        spawnChild: Bool = false,
        crashAfterMillis: Int? = nil,
        stdout: [String] = [],
        stderr: [String] = [],
        invalidUTF8: Bool = false
    ) {
        self.startupDelayMillis = max(0, startupDelayMillis)
        self.readyAfterMillis = max(0, readyAfterMillis)
        self.slp = slp
        self.gracefulStopDelayMillis = max(0, gracefulStopDelayMillis)
        self.ignoreTermination = ignoreTermination
        self.spawnChild = spawnChild
        self.crashAfterMillis = crashAfterMillis
        self.stdout = stdout
        self.stderr = stderr
        self.invalidUTF8 = invalidUTF8
    }
}

public struct LoadStarFixtureEvent: Codable, Equatable, Sendable {
    public let kind: String
    public let message: String?

    public init(kind: String, message: String? = nil) {
        self.kind = kind
        self.message = message
    }
}

import Foundation

public struct ProcessSessionID: Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func new() -> Self {
        Self(rawValue: UUID().uuidString.lowercased())
    }
}

public struct ProcessIdentity: Codable, Equatable, Sendable {
    public let pid: Int32
    public let startedAt: Date
    public let executableReference: String

    public init(pid: Int32, startedAt: Date, executableReference: String) {
        self.pid = pid
        self.startedAt = startedAt
        self.executableReference = executableReference
    }
}

public struct ProcessExit: Codable, Equatable, Sendable {
    public let exitCode: Int32?
    public let signal: Int32?
    public let expected: Bool

    public init(exitCode: Int32? = nil, signal: Int32? = nil, expected: Bool) {
        self.exitCode = exitCode
        self.signal = signal
        self.expected = expected
    }

    public var succeeded: Bool {
        exitCode == 0 && signal == nil
    }
}

public struct LifecycleIssue: Codable, Equatable, Sendable, Error {
    public let code: String
    public let message: String
    public let retryability: Retryability
    public let recoveryAction: RecoveryAction

    public init(
        code: String,
        message: String,
        retryability: Retryability = .userActionRequired,
        recoveryAction: RecoveryAction = .manualRepair
    ) {
        self.code = code
        self.message = message
        self.retryability = retryability
        self.recoveryAction = recoveryAction
    }
}

public struct ReadinessIssue: Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ServerPing: Codable, Equatable, Sendable {
    public let versionName: String?
    public let playersOnline: Int?
    public let playersMax: Int?
    public let description: String?

    public init(
        versionName: String? = nil,
        playersOnline: Int? = nil,
        playersMax: Int? = nil,
        description: String? = nil
    ) {
        self.versionName = versionName
        self.playersOnline = playersOnline
        self.playersMax = playersMax
        self.description = description
    }
}

public enum Readiness: Codable, Equatable, Sendable {
    case unknown
    case probing
    case unconnected(ReadinessIssue?)
    case ready(ServerPing)

    private enum CodingKeys: String, CodingKey {
        case kind
        case issue
        case ping
    }

    private enum Kind: String, Codable {
        case unknown
        case probing
        case unconnected
        case ready
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .unknown: self = .unknown
        case .probing: self = .probing
        case .unconnected: self = .unconnected(try container.decodeIfPresent(ReadinessIssue.self, forKey: .issue))
        case .ready: self = .ready(try container.decode(ServerPing.self, forKey: .ping))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unknown: try container.encode(Kind.unknown, forKey: .kind)
        case .probing: try container.encode(Kind.probing, forKey: .kind)
        case .unconnected(let issue):
            try container.encode(Kind.unconnected, forKey: .kind)
            try container.encodeIfPresent(issue, forKey: .issue)
        case .ready(let ping):
            try container.encode(Kind.ready, forKey: .kind)
            try container.encode(ping, forKey: .ping)
        }
    }
}

public enum ServerLifecycleState: Codable, Equatable, Sendable {
    case offline
    case preparing
    case starting(ProcessIdentity)
    case running
    case stopping
    case stopTimedOut
    case forceTerminationPending
    case crashed(ProcessExit)
    case unmanaged
    case failed(LifecycleIssue)

    private enum CodingKeys: String, CodingKey {
        case kind
        case process
        case exit
        case issue
    }

    private enum Kind: String, Codable {
        case offline
        case preparing
        case starting
        case running
        case stopping
        case stopTimedOut
        case forceTerminationPending
        case crashed
        case unmanaged
        case failed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .offline: self = .offline
        case .preparing: self = .preparing
        case .starting: self = .starting(try container.decode(ProcessIdentity.self, forKey: .process))
        case .running: self = .running
        case .stopping: self = .stopping
        case .stopTimedOut: self = .stopTimedOut
        case .forceTerminationPending: self = .forceTerminationPending
        case .crashed: self = .crashed(try container.decode(ProcessExit.self, forKey: .exit))
        case .unmanaged: self = .unmanaged
        case .failed: self = .failed(try container.decode(LifecycleIssue.self, forKey: .issue))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .offline: try container.encode(Kind.offline, forKey: .kind)
        case .preparing: try container.encode(Kind.preparing, forKey: .kind)
        case .starting(let process):
            try container.encode(Kind.starting, forKey: .kind)
            try container.encode(process, forKey: .process)
        case .running: try container.encode(Kind.running, forKey: .kind)
        case .stopping: try container.encode(Kind.stopping, forKey: .kind)
        case .stopTimedOut: try container.encode(Kind.stopTimedOut, forKey: .kind)
        case .forceTerminationPending: try container.encode(Kind.forceTerminationPending, forKey: .kind)
        case .crashed(let exit):
            try container.encode(Kind.crashed, forKey: .kind)
            try container.encode(exit, forKey: .exit)
        case .unmanaged: try container.encode(Kind.unmanaged, forKey: .kind)
        case .failed(let issue):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(issue, forKey: .issue)
        }
    }
}

public struct ServerActionAvailability: Codable, Equatable, Sendable {
    public let canStop: Bool
    public let canRestart: Bool
    public let canOpenConsole: Bool
    public let canOpenLogs: Bool
    public let canUsePlayerActions: Bool
    public let canUseTPSActions: Bool

    public init(
        canStop: Bool,
        canRestart: Bool,
        canOpenConsole: Bool,
        canOpenLogs: Bool,
        canUsePlayerActions: Bool,
        canUseTPSActions: Bool
    ) {
        self.canStop = canStop
        self.canRestart = canRestart
        self.canOpenConsole = canOpenConsole
        self.canOpenLogs = canOpenLogs
        self.canUsePlayerActions = canUsePlayerActions
        self.canUseTPSActions = canUseTPSActions
    }

    public static func forState(_ lifecycle: ServerLifecycleState, readiness: Readiness) -> Self {
        let processExists: Bool
        switch lifecycle {
        case .starting, .running, .stopping, .stopTimedOut, .forceTerminationPending: processExists = true
        case .offline, .preparing, .crashed, .unmanaged, .failed: processExists = false
        }
        let canStop = processExists && !matchesUnmanaged(lifecycle)
        let canRestart = canStop || matchesCrash(lifecycle)
        let online: Bool
        if case .ready = readiness { online = true } else { online = false }
        return Self(
            canStop: canStop,
            canRestart: canRestart,
            canOpenConsole: processExists,
            canOpenLogs: processExists || matchesCrash(lifecycle),
            canUsePlayerActions: online,
            canUseTPSActions: online
        )
    }

    private static func matchesUnmanaged(_ lifecycle: ServerLifecycleState) -> Bool {
        if case .unmanaged = lifecycle { return true }
        return false
    }

    private static func matchesCrash(_ lifecycle: ServerLifecycleState) -> Bool {
        if case .crashed = lifecycle { return true }
        return false
    }
}

public struct ServerRuntimeSnapshot: Codable, Equatable, Sendable {
    public let serverID: ServerID
    public let lifecycle: ServerLifecycleState
    public let readiness: Readiness
    public let capabilities: ServerActionAvailability

    public init(
        serverID: ServerID,
        lifecycle: ServerLifecycleState,
        readiness: Readiness,
        capabilities: ServerActionAvailability? = nil
    ) {
        self.serverID = serverID
        self.lifecycle = lifecycle
        self.readiness = readiness
        self.capabilities = capabilities ?? .forState(lifecycle, readiness: readiness)
    }
}

public enum EULAState: Codable, Equatable, Sendable {
    case required
    case accepted
    case declined
    case unreadable(LifecycleIssue)

    private enum CodingKeys: String, CodingKey { case kind, issue }
    private enum Kind: String, Codable { case required, accepted, declined, unreadable }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .required: self = .required
        case .accepted: self = .accepted
        case .declined: self = .declined
        case .unreadable: self = .unreadable(try container.decode(LifecycleIssue.self, forKey: .issue))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .required: try container.encode(Kind.required, forKey: .kind)
        case .accepted: try container.encode(Kind.accepted, forKey: .kind)
        case .declined: try container.encode(Kind.declined, forKey: .kind)
        case .unreadable(let issue):
            try container.encode(Kind.unreadable, forKey: .kind)
            try container.encode(issue, forKey: .issue)
        }
    }
}

public enum LaunchIntent: String, Codable, Equatable, Sendable {
    case manual
    case automatic
}

public struct LaunchWarning: Codable, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ConfirmationRequirement: Codable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let intent: LaunchIntent

    public init(code: String, message: String, intent: LaunchIntent) {
        self.code = code
        self.message = message
        self.intent = intent
    }
}

public enum LaunchPreflight: Codable, Equatable, Sendable {
    case ready(warnings: [LaunchWarning])
    case blocked(LifecycleIssue)
    case needsUserConfirmation(ConfirmationRequirement)

    private enum CodingKeys: String, CodingKey { case kind, warnings, issue, requirement }
    private enum Kind: String, Codable { case ready, blocked, needsUserConfirmation }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .ready: self = .ready(warnings: try container.decode([LaunchWarning].self, forKey: .warnings))
        case .blocked: self = .blocked(try container.decode(LifecycleIssue.self, forKey: .issue))
        case .needsUserConfirmation:
            self = .needsUserConfirmation(try container.decode(ConfirmationRequirement.self, forKey: .requirement))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ready(let warnings):
            try container.encode(Kind.ready, forKey: .kind)
            try container.encode(warnings, forKey: .warnings)
        case .blocked(let issue):
            try container.encode(Kind.blocked, forKey: .kind)
            try container.encode(issue, forKey: .issue)
        case .needsUserConfirmation(let requirement):
            try container.encode(Kind.needsUserConfirmation, forKey: .kind)
            try container.encode(requirement, forKey: .requirement)
        }
    }
}

public struct LaunchJavaOverride: Equatable, Sendable {
    public let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }
}

public enum JavaCompatibility: Codable, Equatable, Sendable {
    case compatible
    case mismatch(requiredMajor: Int, actualMajor: Int?)
    case unknown
}

public struct JavaInstallation: Equatable, Sendable {
    public let identifier: String
    public let executableURL: URL
    public let homeURL: URL?
    public let majorVersion: Int?
    public let vendor: String?

    public init(
        identifier: String,
        executableURL: URL,
        homeURL: URL? = nil,
        majorVersion: Int? = nil,
        vendor: String? = nil
    ) {
        self.identifier = identifier
        self.executableURL = executableURL
        self.homeURL = homeURL
        self.majorVersion = majorVersion
        self.vendor = vendor
    }
}

public struct JavaResolution: Equatable, Sendable {
    public let executableURL: URL
    public let installationID: String?
    public let majorVersion: Int?
    public let vendor: String?
    public let compatibility: JavaCompatibility

    public init(
        executableURL: URL,
        installationID: String? = nil,
        majorVersion: Int? = nil,
        vendor: String? = nil,
        compatibility: JavaCompatibility = .unknown
    ) {
        self.executableURL = executableURL
        self.installationID = installationID
        self.majorVersion = majorVersion
        self.vendor = vendor
        self.compatibility = compatibility
    }
}

public struct ProcessLaunchRequest: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]
    public let workingDirectoryURL: URL
    public let environment: [String: String]

    public init(
        executableURL: URL,
        arguments: [String],
        workingDirectoryURL: URL,
        environment: [String: String] = [:]
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.workingDirectoryURL = workingDirectoryURL
        self.environment = environment
    }
}

public struct ProcessSession: Equatable, Sendable {
    public let id: ProcessSessionID
    public let identity: ProcessIdentity

    public init(id: ProcessSessionID, identity: ProcessIdentity) {
        self.id = id
        self.identity = identity
    }
}

public enum ProcessEvent: Equatable, Sendable {
    case started(ProcessIdentity)
    case stdout(String)
    case stderr(String)
    case terminated(ProcessExit)
    case failed(LifecycleIssue)
}

public enum StopTimeoutDecision: String, Codable, Equatable, Sendable {
    case wait
    case force
    case cancel
}

public enum LifecycleEvent: Equatable, Sendable {
    case prepared
    case processSpawned(ProcessIdentity)
    case readinessProbing
    case readinessReady(ServerPing)
    case readinessFailed(ReadinessIssue)
    case stopRequested
    case stopTimedOut
    case forceRequested
    case forceCompleted
    case processExited(ProcessExit)
    case markedUnmanaged
    case failed(LifecycleIssue)
}

public struct ServerLifecycleReducer: Sendable {
    public init() {}

    public static func reduce(_ snapshot: ServerRuntimeSnapshot, event: LifecycleEvent) -> ServerRuntimeSnapshot {
        var lifecycle = snapshot.lifecycle
        var readiness = snapshot.readiness
        switch event {
        case .prepared:
            lifecycle = .preparing
            readiness = .unknown
        case .processSpawned:
            lifecycle = .running
            readiness = .probing
        case .readinessProbing: readiness = .probing
        case .readinessReady(let ping): readiness = .ready(ping)
        case .readinessFailed(let issue): readiness = .unconnected(issue)
        case .stopRequested: lifecycle = .stopping
        case .stopTimedOut: lifecycle = .stopTimedOut
        case .forceRequested: lifecycle = .forceTerminationPending
        case .forceCompleted:
            lifecycle = .offline
            readiness = .unknown
        case .processExited(let exit):
            lifecycle = exit.expected ? .offline : .crashed(exit)
            readiness = exit.expected ? .unknown : snapshot.readiness
        case .markedUnmanaged: lifecycle = .unmanaged
        case .failed(let issue): lifecycle = .failed(issue)
        }
        return ServerRuntimeSnapshot(serverID: snapshot.serverID, lifecycle: lifecycle, readiness: readiness)
    }
}

public enum LifecycleCommandResult: Equatable, Sendable {
    case accepted(ServerRuntimeSnapshot)
    case needsConfirmation(ConfirmationRequirement)
    case failed(LifecycleIssue)
}

public enum TerminationPreparation: Equatable, Sendable {
    case ready
    case waiting(serverIDs: [ServerID])
    case needsDecision(serverIDs: [ServerID])
    case cancelled
}

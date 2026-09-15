import Foundation

public enum SchedulePolicy: Codable, Equatable, Sendable {
    case disabled
    case interval(seconds: Int64)
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int)

    public func validate() throws {
        switch self {
        case .disabled:
            return
        case .interval(let seconds):
            guard seconds > 0 else {
                throw DomainValidationError.invalidSchedule
            }
        case .daily(let hour, let minute):
            guard (0..<24).contains(hour), (0..<60).contains(minute) else {
                throw DomainValidationError.invalidSchedule
            }
        case .weekly(let weekday, let hour, let minute):
            guard (1...7).contains(weekday), (0..<24).contains(hour), (0..<60).contains(minute) else {
                throw DomainValidationError.invalidSchedule
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case seconds
        case weekday
        case hour
        case minute
    }

    private enum Kind: String, Codable {
        case disabled
        case interval
        case daily
        case weekly
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .disabled:
            self = .disabled
        case .interval:
            self = .interval(seconds: try container.decode(Int64.self, forKey: .seconds))
        case .daily:
            self = .daily(
                hour: try container.decode(Int.self, forKey: .hour),
                minute: try container.decode(Int.self, forKey: .minute)
            )
        case .weekly:
            self = .weekly(
                weekday: try container.decode(Int.self, forKey: .weekday),
                hour: try container.decode(Int.self, forKey: .hour),
                minute: try container.decode(Int.self, forKey: .minute)
            )
        }

        try validate()
    }

    public func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .disabled:
            try container.encode(Kind.disabled, forKey: .kind)
        case .interval(let seconds):
            try container.encode(Kind.interval, forKey: .kind)
            try container.encode(seconds, forKey: .seconds)
        case .daily(let hour, let minute):
            try container.encode(Kind.daily, forKey: .kind)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        case .weekly(let weekday, let hour, let minute):
            try container.encode(Kind.weekly, forKey: .kind)
            try container.encode(weekday, forKey: .weekday)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
        }
    }
}

public enum CrashRecoveryMode: String, Codable, Equatable, Sendable {
    case disabled
    case prompt
    case restartAfterFailure
}

public struct CrashRecoveryPolicy: Codable, Equatable, Sendable {
    public let mode: CrashRecoveryMode
    public let delaySeconds: Int64?

    public init(mode: CrashRecoveryMode, delaySeconds: Int64? = nil) throws {
        if mode == .restartAfterFailure {
            guard let delaySeconds, delaySeconds > 0 else {
                throw DomainValidationError.invalidPolicy
            }
        } else if delaySeconds != nil {
            throw DomainValidationError.invalidPolicy
        }

        self.mode = mode
        self.delaySeconds = delaySeconds
    }
}

public struct BackupPolicy: Codable, Equatable, Sendable {
    public let schedule: SchedulePolicy
    public let retentionCount: Int

    public init(schedule: SchedulePolicy, retentionCount: Int) throws {
        guard retentionCount >= 0 else {
            throw DomainValidationError.invalidPolicy
        }

        try schedule.validate()
        self.schedule = schedule
        self.retentionCount = retentionCount
    }
}

public struct NotificationPolicy: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let highCPUAlertsEnabled: Bool

    public init(enabled: Bool, highCPUAlertsEnabled: Bool) {
        self.enabled = enabled
        self.highCPUAlertsEnabled = highCPUAlertsEnabled
    }
}

public struct ServerPolicies: Codable, Equatable, Sendable {
    public let crashRecovery: CrashRecoveryPolicy
    public let backup: BackupPolicy
    public let notifications: NotificationPolicy

    public init(
        crashRecovery: CrashRecoveryPolicy,
        backup: BackupPolicy,
        notifications: NotificationPolicy
    ) {
        self.crashRecovery = crashRecovery
        self.backup = backup
        self.notifications = notifications
    }

    public func validate() throws {
        _ = try CrashRecoveryPolicy(mode: crashRecovery.mode, delaySeconds: crashRecovery.delaySeconds)
        _ = try BackupPolicy(schedule: backup.schedule, retentionCount: backup.retentionCount)
    }
}

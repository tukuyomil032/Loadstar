import Darwin
import Foundation
import LoadStarDomain

public enum ProcessControllerError: Error, Equatable, Sendable {
    case launchFailed(String)
    case unknownSession(ProcessSessionID)
    case alreadyExited(ProcessSessionID)
    case signalFailed(ProcessSessionID, signal: Int32)
}

public protocol ProcessController: Sendable {
    func launch(_ request: ProcessLaunchRequest) async throws -> ProcessSession
    func events(for sessionID: ProcessSessionID) async -> AsyncStream<ProcessEvent>
    func requestGracefulStop(_ sessionID: ProcessSessionID) async throws
    func requestForceStop(_ sessionID: ProcessSessionID) async throws
    func waitForExit(_ sessionID: ProcessSessionID) async -> ProcessExit?
}

/// Owns Foundation.Process and the process group. No process handles escape this actor.
public actor LocalProcessController: ProcessController {
    private final class SessionState {
        let process: Process
        let stdout: Pipe
        let stderr: Pipe
        let session: ProcessSession
        var expectedTermination = false
        var events: [ProcessEvent] = []
        var continuations: [UUID: AsyncStream<ProcessEvent>.Continuation] = [:]
        var exit: ProcessExit?
        var waiters: [CheckedContinuation<ProcessExit?, Never>] = []

        init(process: Process, stdout: Pipe, stderr: Pipe, session: ProcessSession) {
            self.process = process
            self.stdout = stdout
            self.stderr = stderr
            self.session = session
        }
    }

    private var sessions: [ProcessSessionID: SessionState] = [:]

    public init() {}

    public func launch(_ request: ProcessLaunchRequest) async throws -> ProcessSession {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectoryURL
        process.environment = ProcessInfo.processInfo.environment.merging(request.environment) { _, new in new }
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ProcessControllerError.launchFailed("process.launch.failed")
        }

        let identity = ProcessIdentity(
            pid: process.processIdentifier,
            startedAt: Date(),
            executableReference: request.executableURL.lastPathComponent
        )
        let session = ProcessSession(id: .new(), identity: identity)
        let state = SessionState(process: process, stdout: stdout, stderr: stderr, session: session)
        sessions[session.id] = state
        _ = setpgid(process.processIdentifier, process.processIdentifier)

        configurePipe(stdout, for: session.id, event: { .stdout($0) })
        configurePipe(stderr, for: session.id, event: { .stderr($0) })
        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleTermination(of: session.id, process: process)
            }
        }
        emit(.started(identity), for: session.id)
        return session
    }

    public func events(for sessionID: ProcessSessionID) async -> AsyncStream<ProcessEvent> {
        AsyncStream { continuation in
            guard let state = sessions[sessionID] else {
                continuation.yield(
                    .failed(
                        LifecycleIssue(
                            code: "server.process.unknownSession",
                            message: "The process session is no longer available.",
                            recoveryAction: .retry
                        )))
                continuation.finish()
                return
            }
            let id = UUID()
            state.continuations[id] = continuation
            for event in state.events {
                continuation.yield(event)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id, from: sessionID) }
            }
        }
    }

    public func requestGracefulStop(_ sessionID: ProcessSessionID) async throws {
        guard let state = sessions[sessionID] else { throw ProcessControllerError.unknownSession(sessionID) }
        guard state.exit == nil else { throw ProcessControllerError.alreadyExited(sessionID) }
        state.expectedTermination = true
        try signalGroup(for: state.process.processIdentifier, signal: SIGTERM, sessionID: sessionID)
    }

    public func requestForceStop(_ sessionID: ProcessSessionID) async throws {
        guard let state = sessions[sessionID] else { throw ProcessControllerError.unknownSession(sessionID) }
        guard state.exit == nil else { throw ProcessControllerError.alreadyExited(sessionID) }
        state.expectedTermination = true
        try signalGroup(for: state.process.processIdentifier, signal: SIGKILL, sessionID: sessionID)
    }

    public func waitForExit(_ sessionID: ProcessSessionID) async -> ProcessExit? {
        guard let state = sessions[sessionID] else { return nil }
        if let exit = state.exit { return exit }
        return await withCheckedContinuation { continuation in
            state.waiters.append(continuation)
        }
    }

    private func configurePipe(
        _ pipe: Pipe,
        for sessionID: ProcessSessionID,
        event: @escaping @Sendable (String) -> ProcessEvent
    ) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { await self?.emit(event(text), for: sessionID) }
        }
    }

    private func emit(_ event: ProcessEvent, for sessionID: ProcessSessionID) {
        guard let state = sessions[sessionID] else { return }
        state.events.append(event)
        if state.events.count > 1_000 {
            state.events.removeFirst(state.events.count - 1_000)
        }
        for continuation in state.continuations.values {
            continuation.yield(event)
        }
    }

    private func handleTermination(of sessionID: ProcessSessionID, process: Process) {
        guard let state = sessions[sessionID], state.exit == nil else { return }
        state.stdout.fileHandleForReading.readabilityHandler = nil
        state.stderr.fileHandleForReading.readabilityHandler = nil
        let status = process.terminationStatus
        let signal = process.terminationReason == .uncaughtSignal ? status : nil
        let exitCode = process.terminationReason == .exit ? status : nil
        let exit = ProcessExit(exitCode: exitCode, signal: signal, expected: state.expectedTermination)
        state.exit = exit
        emit(.terminated(exit), for: sessionID)
        for continuation in state.continuations.values {
            continuation.finish()
        }
        state.continuations.removeAll()
        for waiter in state.waiters {
            waiter.resume(returning: exit)
        }
        state.waiters.removeAll()
    }

    private func removeContinuation(_ id: UUID, from sessionID: ProcessSessionID) {
        sessions[sessionID]?.continuations.removeValue(forKey: id)
    }

    private func signalGroup(for pid: Int32, signal: Int32, sessionID: ProcessSessionID) throws {
        guard kill(-pid, signal) == 0 || kill(pid, signal) == 0 else {
            throw ProcessControllerError.signalFailed(sessionID, signal: signal)
        }
    }
}

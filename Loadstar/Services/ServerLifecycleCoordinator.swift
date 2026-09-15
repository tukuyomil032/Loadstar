import Foundation
import LoadStarDomain
import LoadStarPlatform

// swiftlint:disable type_body_length
public protocol LifecycleSleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct SystemLifecycleSleeper: LifecycleSleeper {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
public actor ServerLifecycleCoordinator {
    private struct Session {
        let process: ProcessSession
        let port: Int
        var snapshot: ServerRuntimeSnapshot
        var operationID: OperationID
        var stopRequested = false
        var eventTask: Task<Void, Never>?
        var readinessTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?
    }

    private let metadataRepository: any ServerMetadataRepository
    private let fileSystem: any FileSystemClient
    private let javaProvider: any JavaRuntimeProvider
    private let processController: any ProcessController
    private let pingClient: any ServerListPingClient
    private let eulaService: any EULAService
    private let checkpointStore: any LifecycleCheckpointStore
    private let sleeper: any LifecycleSleeper
    private let serverDirectoryURL: @Sendable (ServerID) -> URL
    private let maxRunningServers: Int
    private var sessions: [ServerID: Session] = [:]
    private var selectedServerID: ServerID?
    private var unmanaged: Set<ServerID> = []

    public init(
        metadataRepository: any ServerMetadataRepository,
        fileSystem: any FileSystemClient,
        javaProvider: any JavaRuntimeProvider,
        processController: any ProcessController,
        pingClient: any ServerListPingClient,
        eulaService: any EULAService,
        checkpointStore: any LifecycleCheckpointStore,
        sleeper: any LifecycleSleeper = SystemLifecycleSleeper(),
        serverDirectoryURL: @escaping @Sendable (ServerID) -> URL = { _ in FileManager.default.temporaryDirectory },
        maxRunningServers: Int = 8
    ) {
        self.metadataRepository = metadataRepository
        self.fileSystem = fileSystem
        self.javaProvider = javaProvider
        self.processController = processController
        self.pingClient = pingClient
        self.eulaService = eulaService
        self.checkpointStore = checkpointStore
        self.sleeper = sleeper
        self.serverDirectoryURL = serverDirectoryURL
        self.maxRunningServers = maxRunningServers
    }

    public func start(
        serverID: ServerID,
        intent: LaunchIntent,
        customJava: LaunchJavaOverride? = nil
    ) async -> LifecycleCommandResult {
        if let session = sessions[serverID] {
            return .accepted(session.snapshot)
        }
        guard runningCount < maxRunningServers else {
            return .failed(
                LifecycleIssue(
                    code: "server.start.capacityExceeded",
                    message: "LoadStar can run at most eight managed servers.",
                    recoveryAction: .manualRepair
                ))
        }
        if unmanaged.contains(serverID) {
            return .failed(
                LifecycleIssue(
                    code: "server.start.unmanaged",
                    message: "This server is unmanaged after relaunch and needs an explicit probe.",
                    recoveryAction: .manualRepair
                ))
        }

        let initial = ServerRuntimeSnapshot(serverID: serverID, lifecycle: .preparing, readiness: .unknown)
        let operationID = OperationID.new()
        do {
            try await checkpoint(initial, stage: .launch, operationID: operationID)
            let metadata = try await metadataRepository.load(serverID: serverID)
            let serverDirectory = try ManagedPath.serverDirectory(for: serverID)
            let preflight = LaunchPreflightService(
                javaProvider: javaProvider,
                fileSystem: fileSystem,
                eulaService: eulaService,
                serverDirectory: serverDirectory
            )
            let report = await preflight.evaluate(metadata: metadata, intent: intent, customJava: customJava)
            switch report.result {
            case .blocked(let issue): return .failed(issue)
            case .needsUserConfirmation(let requirement): return .needsConfirmation(requirement)
            case .ready:
                guard let java = report.javaResolution else {
                    return .failed(
                        LifecycleIssue(
                            code: "java.resolve.missingResult",
                            message: "Java resolution did not produce an executable.",
                            recoveryAction: .manualRepair
                        ))
                }
                let arguments =
                    report.validatedJVMArguments
                    + [
                        "-Xmx\(metadata.runtimeConfiguration.memoryMiB)M", "-jar",
                        metadata.runtimeConfiguration.jarFileName,
                    ]
                let request = ProcessLaunchRequest(
                    executableURL: java.executableURL,
                    arguments: arguments,
                    workingDirectoryURL: serverDirectoryURL(serverID)
                )
                let process = try await processController.launch(request)
                let snapshot = ServerRuntimeSnapshot(
                    serverID: serverID,
                    lifecycle: .running,
                    readiness: .probing
                )
                var session = Session(
                    process: process,
                    port: metadata.runtimeConfiguration.serverPort,
                    snapshot: snapshot,
                    operationID: operationID
                )
                sessions[serverID] = session
                selectedServerID = serverID
                session.eventTask = observeProcess(process.id, serverID: serverID)
                session.readinessTask = observeReadiness(
                    serverID: serverID, port: metadata.runtimeConfiguration.serverPort)
                sessions[serverID] = session
                try await checkpoint(snapshot, stage: .probing, operationID: operationID, sessionID: process.id)
                return .accepted(snapshot)
            }
        } catch let issue as LifecycleIssue {
            return .failed(issue)
        } catch let error as ProcessControllerError {
            return .failed(
                LifecycleIssue(
                    code: "server.start.processFailed",
                    message: String(describing: error),
                    retryability: .retryable,
                    recoveryAction: .retry
                ))
        } catch {
            return .failed(
                LifecycleIssue(
                    code: "server.start.failed",
                    message: "The server could not be started.",
                    retryability: .retryable,
                    recoveryAction: .retry
                ))
        }
    }

    public func stop(serverID: ServerID) async -> LifecycleCommandResult {
        guard var session = sessions[serverID] else {
            return .failed(
                LifecycleIssue(
                    code: "server.stop.unknownSession",
                    message: "The server is not currently managed by this process.",
                    recoveryAction: .retry
                ))
        }
        do {
            try await processController.requestGracefulStop(session.process.id)
            session.stopRequested = true
            session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: .stopRequested)
            session.timeoutTask?.cancel()
            let operationID = session.operationID
            sessions[serverID] = session
            session.timeoutTask = scheduleStopTimeout(serverID: serverID, operationID: operationID)
            sessions[serverID] = session
            try await checkpoint(
                session.snapshot, stage: .stopping, operationID: operationID, sessionID: session.process.id)
            return .accepted(session.snapshot)
        } catch let error as ProcessControllerError {
            return .failed(
                LifecycleIssue(
                    code: "server.stop.failed",
                    message: String(describing: error),
                    retryability: .retryable,
                    recoveryAction: .retry
                ))
        } catch {
            return .failed(
                LifecycleIssue(
                    code: "server.stop.failed",
                    message: "The graceful stop request failed.",
                    retryability: .retryable,
                    recoveryAction: .retry
                ))
        }
    }

    public func decideStopTimeout(
        serverID: ServerID,
        decision: StopTimeoutDecision
    ) async -> LifecycleCommandResult {
        guard var session = sessions[serverID] else {
            return .failed(
                LifecycleIssue(
                    code: "server.stop.unknownSession",
                    message: "The server is no longer managed by this process.",
                    recoveryAction: .retry
                ))
        }
        switch decision {
        case .wait:
            return .accepted(session.snapshot)
        case .cancel:
            session.stopRequested = false
            session.snapshot = ServerRuntimeSnapshot(
                serverID: serverID, lifecycle: .running, readiness: session.snapshot.readiness)
            session.timeoutTask?.cancel()
            sessions[serverID] = session
            return .accepted(session.snapshot)
        case .force:
            session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: .forceRequested)
            session.timeoutTask?.cancel()
            sessions[serverID] = session
            try? await checkpoint(
                session.snapshot, stage: .forceTerminationPending, operationID: session.operationID,
                sessionID: session.process.id)
            Task { [weak self] in
                guard let self else { return }
                try? await self.sleeper.sleep(for: .seconds(10))
                await self.forceStopIfNeeded(serverID: serverID)
            }
            return .accepted(session.snapshot)
        }
    }

    public func prepareForApplicationTermination() async -> TerminationPreparation {
        let ids = Array(sessions.keys)
        guard !ids.isEmpty else { return .ready }
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { _ = await self.stop(serverID: id) }
            }
        }
        return .waiting(serverIDs: ids)
    }

    public func snapshots() -> [ServerID: ServerRuntimeSnapshot] {
        Dictionary(uniqueKeysWithValues: sessions.map { ($0.key, $0.value.snapshot) })
            .merging(
                unmanaged.map { ($0, ServerRuntimeSnapshot(serverID: $0, lifecycle: .unmanaged, readiness: .unknown)) }
            ) { current, _ in current }
    }

    public func markUnmanaged(serverID: ServerID) {
        unmanaged.insert(serverID)
    }

    public func select(serverID: ServerID?) {
        if selectedServerID != serverID, let old = selectedServerID {
            sessions[old]?.readinessTask?.cancel()
        }
        selectedServerID = serverID
        if let serverID, let session = sessions[serverID], session.readinessTask == nil {
            sessions[serverID]?.readinessTask = observeReadiness(serverID: serverID, port: session.port)
        }
    }

    private var runningCount: Int {
        sessions.values.filter {
            switch $0.snapshot.lifecycle {
            case .starting, .running, .stopping, .stopTimedOut, .forceTerminationPending: return true
            default: return false
            }
        }.count
    }

    private func observeProcess(_ sessionID: ProcessSessionID, serverID: ServerID) -> Task<Void, Never> {
        let controller = processController
        return Task { [weak self] in
            let events = await controller.events(for: sessionID)
            for await event in events {
                await self?.handle(event, serverID: serverID)
            }
        }
    }

    private func observeReadiness(serverID: ServerID, port: Int) -> Task<Void, Never> {
        let client = pingClient
        let sleeper = self.sleeper
        return Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let ping = try await client.ping(host: "127.0.0.1", port: port, timeout: .seconds(3))
                    await self?.handleReadiness(.ready(ping), serverID: serverID)
                } catch {
                    await self?.handleReadiness(
                        .unconnected(
                            ReadinessIssue(
                                code: "server.readiness.unconnected",
                                message: "The server process is running but did not answer SLP.")), serverID: serverID)
                }
                do { try await sleeper.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    private func scheduleStopTimeout(serverID: ServerID, operationID: OperationID) -> Task<Void, Never> {
        let sleeper = self.sleeper
        return Task { [weak self] in
            try? await sleeper.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await self?.markStopTimedOut(serverID: serverID, operationID: operationID)
        }
    }

    private func markStopTimedOut(serverID: ServerID, operationID: OperationID) {
        guard var session = sessions[serverID], session.operationID == operationID, session.stopRequested else {
            return
        }
        session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: .stopTimedOut)
        sessions[serverID] = session
        Task {
            try? await checkpoint(
                session.snapshot, stage: .stopping, operationID: operationID, sessionID: session.process.id)
        }
    }

    private func forceStopIfNeeded(serverID: ServerID) async {
        guard let session = sessions[serverID], session.snapshot.lifecycle == .forceTerminationPending else { return }
        try? await processController.requestForceStop(session.process.id)
    }

    private func handle(_ event: ProcessEvent, serverID: ServerID) async {
        guard var session = sessions[serverID] else { return }
        switch event {
        case .started(let identity):
            session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: .processSpawned(identity))
        case .stdout, .stderr:
            break
        case .terminated(let exit):
            session.readinessTask?.cancel()
            session.timeoutTask?.cancel()
            session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: .processExited(exit))
            if case .crashed = session.snapshot.lifecycle {
                try? await checkpoint(
                    session.snapshot, stage: .crash, operationID: session.operationID, sessionID: session.process.id)
            } else {
                try? await checkpoint(
                    session.snapshot, stage: .cleanup, operationID: session.operationID, sessionID: session.process.id)
            }
            sessions.removeValue(forKey: serverID)
            return
        case .failed(let issue):
            session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: .failed(issue))
        }
        sessions[serverID] = session
        if case .ready = session.snapshot.readiness {
            try? await checkpoint(
                session.snapshot, stage: .probing, operationID: session.operationID, sessionID: session.process.id)
        }
    }

    private func handleReadiness(_ readiness: Readiness, serverID: ServerID) async {
        guard var session = sessions[serverID] else { return }
        let event: LifecycleEvent
        switch readiness {
        case .ready(let ping): event = .readinessReady(ping)
        case .unconnected(let issue):
            event = .readinessFailed(
                issue
                    ?? ReadinessIssue(
                        code: "server.readiness.unconnected",
                        message: "The server process is running but did not answer SLP."
                    ))
        case .probing: event = .readinessProbing
        case .unknown: return
        }
        session.snapshot = ServerLifecycleReducer.reduce(session.snapshot, event: event)
        sessions[serverID] = session
        try? await checkpoint(
            session.snapshot,
            stage: .probing,
            operationID: session.operationID,
            sessionID: session.process.id
        )
    }

    private func checkpoint(
        _ snapshot: ServerRuntimeSnapshot,
        stage: LifecycleCheckpointStage,
        operationID: OperationID,
        sessionID: ProcessSessionID? = nil
    ) async throws {
        let payload = LifecycleCheckpointPayload(stage: stage, serverID: snapshot.serverID, sessionID: sessionID)
        let payloadData = try JSONEncoder().encode(payload)
        let json = try JSONDecoder().decode(JSONValue.self, from: payloadData)
        let checkpoint = try OperationCheckpoint(
            id: operationID,
            serverID: snapshot.serverID,
            stage: stage == .cleanup ? .completed : .staging,
            status: stage == .cleanup ? .succeeded : .running,
            progress: stage == .cleanup ? 1 : 0,
            checkpointPayload: json
        )
        try await checkpointStore.save(checkpoint)
    }
}
// swiftlint:enable type_body_length

import LoadStarDomain
import LoadStarServices
import Observation

@MainActor
@Observable
public final class ServerLifecycleFeature {
    private let coordinator: ServerLifecycleCoordinator
    public private(set) var snapshots: [ServerID: ServerRuntimeSnapshot] = [:]

    public init(coordinator: ServerLifecycleCoordinator) {
        self.coordinator = coordinator
    }

    public func refresh() async {
        snapshots = await coordinator.snapshots()
    }

    public func stop(serverID: ServerID) async {
        _ = await coordinator.stop(serverID: serverID)
        await refresh()
    }
}

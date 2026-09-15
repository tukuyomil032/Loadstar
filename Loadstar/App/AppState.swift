import LoadStarDomain
import LoadStarServices
import Observation

@MainActor
@Observable
final class AppState {
    var isFirstLaunch = true
    private(set) var snapshots: [ServerID: ServerRuntimeSnapshot] = [:]
    private let uiTestMode: Bool

    init(uiTestMode: Bool = false) {
        self.uiTestMode = uiTestMode
        if uiTestMode {
            let id = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
            snapshots[id] = ServerRuntimeSnapshot(serverID: id, lifecycle: .running, readiness: .probing)
        }
    }

    func observe(_ coordinator: ServerLifecycleCoordinator?) async {
        guard !uiTestMode, let coordinator else { return }
        while !Task.isCancelled {
            snapshots = await coordinator.snapshots()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

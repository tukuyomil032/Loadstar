import AppKit
import LoadStarDomain
import LoadStarServices

@MainActor
final class LoadStarAppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = LoadStarServices.makeLifecycleCoordinator(debug: true)
    private var terminationInProgress = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        guard !terminationInProgress else { return .terminateLater }
        terminationInProgress = true
        Task { @MainActor in
            let preparation = await coordinator.prepareForApplicationTermination()
            switch preparation {
            case .ready:
                sender.reply(toApplicationShouldTerminate: true)
            case .waiting(let serverIDs):
                await waitForManagedServersToExit(serverIDs, sender: sender, coordinator: coordinator)
            case .needsDecision, .cancelled:
                terminationInProgress = false
                sender.reply(toApplicationShouldTerminate: false)
            }
        }
        return .terminateLater
    }

    private func waitForManagedServersToExit(
        _ serverIDs: [ServerID],
        sender: NSApplication,
        coordinator: ServerLifecycleCoordinator
    ) async {
        for _ in 0..<300 {
            let snapshots = await coordinator.snapshots()
            if !serverIDs.contains(where: { snapshots[$0] != nil }) {
                sender.reply(toApplicationShouldTerminate: true)
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        terminationInProgress = false
        sender.reply(toApplicationShouldTerminate: false)
    }
}

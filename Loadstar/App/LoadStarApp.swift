import LoadStarServices
import LoadStarUI
import SwiftUI

@main
struct LoadStarApp: App {
    @NSApplicationDelegateAdaptor(LoadStarAppDelegate.self) private var appDelegate
    @State private var appState = AppState(
        uiTestMode: ProcessInfo.processInfo.environment["LOADSTAR_UI_TEST_MODE"] == "1"
    )
    private let dependencyContainer = AppDependencyContainer()

    var body: some Scene {
        WindowGroup("LoadStar") {
            DashboardView(snapshot: appState.snapshots.values.first)
                .environment(appState)
                .task {
                    await appState.observe(dependencyContainer.coordinator)
                }
        }

        Settings {
            SettingsView()
        }
    }
}

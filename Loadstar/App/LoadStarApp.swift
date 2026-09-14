import LoadStarUI
import SwiftUI

@main
struct LoadStarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("LoadStar") {
            DashboardView()
                .environment(appState)
        }

        Settings {
            SettingsView()
        }
    }
}

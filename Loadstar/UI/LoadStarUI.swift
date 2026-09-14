import SwiftUI

public struct DashboardView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView(
            "No Servers",
            systemImage: "server.rack",
            description: Text("Add a Minecraft server to get started.")
        )
        .frame(minWidth: 760, minHeight: 480)
    }
}

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        Form {
            Section("General") {
                Text("LoadStar settings will be added here.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding()
    }
}

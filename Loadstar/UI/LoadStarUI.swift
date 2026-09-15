import LoadStarDomain
import SwiftUI

public struct DashboardView: View {
    private let snapshot: ServerRuntimeSnapshot

    public init(snapshot: ServerRuntimeSnapshot? = nil) {
        let id = ServerID(rawValue: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        self.snapshot = snapshot ?? ServerRuntimeSnapshot(serverID: id, lifecycle: .offline, readiness: .unknown)
    }

    public var body: some View {
        ServerLifecycleView(snapshot: snapshot)
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

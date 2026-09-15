import LoadStarDomain
import SwiftUI

public struct ServerLifecycleView: View {
    public let snapshot: ServerRuntimeSnapshot
    @State private var eulaAccepted = false

    public init(snapshot: ServerRuntimeSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Server lifecycle", systemImage: "server.rack")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(processLabel)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("server.process.status")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Process: \(processLabel)")
                    .accessibilityIdentifier("server.process.status.detail")
                Text("Readiness: \(readinessLabel)")
                    .accessibilityIdentifier("server.readiness.status")
            }
            HStack(spacing: 12) {
                Button("Stop") {}
                    .disabled(!snapshot.capabilities.canStop)
                    .accessibilityIdentifier("server.capability.stop")
                Button("Restart") {}
                    .disabled(!snapshot.capabilities.canRestart)
                    .accessibilityIdentifier("server.capability.restart")
                Button("Console") {}
                    .disabled(!snapshot.capabilities.canOpenConsole)
                    .accessibilityIdentifier("server.capability.console")
                Button("Logs") {}
                    .disabled(!snapshot.capabilities.canOpenLogs)
                    .accessibilityIdentifier("server.capability.logs")
            }
            Divider()
            Toggle("I have reviewed and accept the Minecraft EULA", isOn: $eulaAccepted)
                .accessibilityIdentifier("server.eula.checkbox")
            Button("Launch") {}
                .disabled(!eulaAccepted)
                .accessibilityIdentifier("server.launch.button")
            Text(snapshot.capabilities.canUsePlayerActions ? "SLP actions available" : "SLP actions unavailable")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("server.slp.actions")
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 480, alignment: .topLeading)
    }

    private var processLabel: String {
        switch snapshot.lifecycle {
        case .offline: return "Offline"
        case .preparing: return "Preparing"
        case .starting: return "Starting"
        case .running: return "Running"
        case .stopping, .stopTimedOut, .forceTerminationPending: return "Stopping"
        case .crashed: return "Crashed"
        case .unmanaged: return "Unmanaged"
        case .failed: return "Failed"
        }
    }

    private var readinessLabel: String {
        switch snapshot.readiness {
        case .unknown: return "Unknown"
        case .probing: return "Connecting"
        case .unconnected: return "Unavailable"
        case .ready: return "Online"
        }
    }
}

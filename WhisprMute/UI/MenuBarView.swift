import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    let quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.vertical, 8)

            // Status
            statusSection

            Divider()
                .padding(.vertical, 8)

            // Meeting Apps
            meetingAppsSection

            Divider()
                .padding(.vertical, 8)

            // Actions
            actionsSection
        }
        .padding(12)
        .frame(width: 280)
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("WhisprMute")
                    .font(.headline)
                Text("Auto-mute for Wispr Flow")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $appState.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.subheadline)

                Spacer()
            }

            if appState.isWisprFlowActive {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.orange)
                    Text("Wispr Flow is recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !appState.mutedApps.isEmpty {
                HStack {
                    Image(systemName: "speaker.slash.fill")
                        .foregroundColor(.red)
                    Text("\(appState.mutedApps.count) app(s) muted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var statusColor: Color {
        if !appState.isEnabled {
            return .gray
        } else if appState.isWisprFlowActive {
            return .orange
        } else {
            return .green
        }
    }

    private var statusText: String {
        if !appState.isEnabled {
            return "Disabled"
        } else if appState.isWisprFlowActive {
            return "Actively muting"
        } else {
            return "Monitoring"
        }
    }

    private var meetingAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Meeting Apps")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if appState.detectedMeetingApps.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.secondary)
                    Text("No meeting apps running")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(appState.detectedMeetingApps, id: \.self) { appName in
                    MeetingAppRow(
                        appName: appName,
                        isMuted: appState.mutedApps.contains(appName),
                        isEnabled: appState.enabledApps.contains(appName)
                    )
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 4) {
            settingsButton
                .padding(.vertical, 4)

            Button(action: quitAction) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit WhisprMute")
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsButtonContent
            }
            .buttonStyle(.plain)
        } else {
            Button(action: openSettingsLegacy) {
                settingsButtonContent
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsButtonContent: some View {
        HStack {
            Image(systemName: "gear")
            Text("Settings")
            Spacer()
            Text("\u{2318},")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func openSettingsLegacy() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MeetingAppRow: View {
    let appName: String
    let isMuted: Bool
    let isEnabled: Bool

    var body: some View {
        HStack {
            if let appType = MeetingAppType(rawValue: appName) {
                Image(systemName: appType.iconName)
                    .frame(width: 20)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }

            Text(appName)
                .font(.subheadline)
                .foregroundColor(isEnabled ? .primary : .secondary)

            Spacer()

            if isMuted {
                Label("Muted", systemImage: "speaker.slash.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .labelStyle(.iconOnly)
            }

            if !isEnabled {
                Text("Disabled")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MenuBarView(
        appState: {
            let state = AppState()
            state.detectedMeetingApps = ["Zoom", "Discord"]
            state.mutedApps = ["Zoom"]
            state.isWisprFlowActive = true
            return state
        }(),
        quitAction: {}
    )
}

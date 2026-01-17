import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPermissionsAlert = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            appsTab
                .tabItem {
                    Label("Apps", systemImage: "app.badge.checkmark")
                }

            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Enable WhisprMute", isOn: $appState.isEnabled)
                    .toggleStyle(.switch)

                Toggle("Launch at Login", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .disabled(true)
                    .help("Coming soon")
            } header: {
                Text("General")
            }

            Section {
                Text("WhisprMute automatically mutes your meeting apps when Wispr Flow starts dictation, then unmutes when done.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("How it works")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appsTab: some View {
        Form {
            Section {
                ForEach(MeetingAppType.allCases, id: \.rawValue) { appType in
                    Toggle(isOn: Binding(
                        get: { appState.enabledApps.contains(appType.rawValue) },
                        set: { enabled in
                            if enabled {
                                appState.enabledApps.insert(appType.rawValue)
                            } else {
                                appState.enabledApps.remove(appType.rawValue)
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: appType.iconName)
                                .frame(width: 24)
                            Text(appType.rawValue)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            } header: {
                Text("Meeting Apps to Control")
            } footer: {
                Text("Select which apps should be muted when Wispr Flow is active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var permissionsTab: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to control mute buttons in other apps",
                    isGranted: checkAccessibilityPermission(),
                    action: openAccessibilitySettings
                )

                PermissionRow(
                    title: "Automation",
                    description: "Required to send commands to meeting apps",
                    isGranted: true, // Can't easily check this
                    action: openAutomationSettings
                )
            } header: {
                Text("Required Permissions")
            } footer: {
                Text("WhisprMute needs these permissions to control your meeting apps. Click the buttons to open System Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("WhisprMute")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Automatically mute meeting apps when using Wispr Flow dictation.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Link("View on GitHub", destination: URL(string: "https://github.com/ItsDlylan/WhisprMute")!)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .fontWeight(.medium)

                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

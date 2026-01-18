import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPermissionsAlert = false
    @State private var chromeDebugStatus: ChromeDebugHelper.ChromeDebugStatus = .chromeNotRunning
    @State private var isRestartingChrome = false
    @State private var availableProfiles: [ChromeProfile] = []
    @AppStorage("selectedChromeProfileId") private var selectedProfileId: String = "Default"

    // Permission states (refreshed periodically)
    @State private var hasAccessibilityPermission = false
    @State private var hasCameraPermission = false
    @State private var hasMicrophonePermission = false

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
        .frame(width: 450, height: 380)
        .onAppear {
            loadProfiles()
            refreshChromeStatus()
            refreshPermissions()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        hasAccessibilityPermission = checkAccessibilityPermission()
        hasCameraPermission = checkCameraPermission()
        hasMicrophonePermission = checkMicrophonePermission()

        print("[Permissions] Accessibility: \(hasAccessibilityPermission), Camera: \(hasCameraPermission), Mic: \(hasMicrophonePermission)")
        print("[Permissions] Camera status: \(AVCaptureDevice.authorizationStatus(for: .video).rawValue), Mic status: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
    }

    private func refreshChromeStatus() {
        // Run on background thread to avoid blocking UI with network call
        DispatchQueue.global(qos: .userInitiated).async {
            let status = ChromeDebugHelper.shared.getStatus()
            DispatchQueue.main.async {
                chromeDebugStatus = status
            }
        }
    }

    private func loadProfiles() {
        availableProfiles = ChromeDebugHelper.shared.getAvailableProfiles()
        // Ensure selected profile exists in available profiles
        if !availableProfiles.contains(where: { $0.id == selectedProfileId }) {
            selectedProfileId = availableProfiles.first?.id ?? "Default"
        }
    }

    private var selectedProfile: ChromeProfile {
        availableProfiles.first(where: { $0.id == selectedProfileId }) ?? ChromeProfile(id: "Default", displayName: "Default")
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
                    isGranted: hasAccessibilityPermission,
                    action: openAccessibilitySettings
                )

                PermissionRow(
                    title: "Automation",
                    description: "Required to send commands to meeting apps",
                    isGranted: true, // Can't easily check this
                    action: openAutomationSettings
                )

                PermissionRow(
                    title: "Camera",
                    description: "Required for Chrome debug mode (Google Meet)",
                    isGranted: hasCameraPermission,
                    action: openCameraSettings
                )

                PermissionRow(
                    title: "Microphone",
                    description: "Required for Chrome debug mode (Google Meet)",
                    isGranted: hasMicrophonePermission,
                    action: openMicrophoneSettings
                )
            } header: {
                Text("Required Permissions")
            } footer: {
                Text("WhisprMute needs these permissions to control your meeting apps. Click the buttons to open System Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                // Profile picker
                Picker("Chrome Profile", selection: $selectedProfileId) {
                    ForEach(availableProfiles) { profile in
                        Text(profile.displayName).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)

                ChromeDebugRow(
                    status: chromeDebugStatus,
                    isRestarting: isRestartingChrome,
                    hasClonedProfile: ChromeDebugHelper.shared.hasClonedProfile(),
                    onSetup: setupChromeDebugMode,
                    onRefresh: refreshChromeStatus
                )
            } header: {
                Text("Google Meet Setup")
            } footer: {
                Text("Creates a separate Chrome profile for debug mode. Your settings, bookmarks, passwords, history, extensions, and login sessions will be copied.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setupChromeDebugMode() {
        isRestartingChrome = true
        let isFirstTimeSetup = !ChromeDebugHelper.shared.hasClonedProfile()

        // Request media permissions first if this is first-time setup
        let proceedWithSetup = {
            // Clone the selected profile
            DispatchQueue.global(qos: .userInitiated).async {
                let cloneSuccess = ChromeDebugHelper.shared.cloneProfile(profileId: self.selectedProfileId)

                DispatchQueue.main.async {
                    if cloneSuccess {
                        // Now restart Chrome with debug mode
                        ChromeDebugHelper.shared.restartChromeWithDebugMode { success in
                            self.isRestartingChrome = false
                            self.refreshChromeStatus()
                        }
                    } else {
                        self.isRestartingChrome = false
                        print("[SettingsView] Failed to clone profile")
                    }
                }
            }
        }

        if isFirstTimeSetup {
            // Request camera/mic permissions before proceeding
            ChromeDebugHelper.shared.requestMediaPermissions {
                proceedWithSetup()
            }
        } else {
            proceedWithSetup()
        }
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
        // Trigger the system prompt to add the app to Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    private func checkCameraPermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            // Request permission if not yet determined
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { self.refreshPermissions() }
            }
        }
        return status == .authorized
    }

    private func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            // Request permission if not yet determined
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { self.refreshPermissions() }
            }
        }
        return status == .authorized
    }

    private func openCameraSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
    }

    private func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
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

struct ChromeDebugRow: View {
    let status: ChromeDebugHelper.ChromeDebugStatus
    let isRestarting: Bool
    let hasClonedProfile: Bool
    let onSetup: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Chrome Debug Mode")
                        .fontWeight(.medium)

                    statusIcon
                }

                Text(statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isRestarting {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 60)
            } else {
                HStack(spacing: 8) {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh status")

                    if status != .debugModeEnabled {
                        Button(buttonTitle) {
                            onSetup()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var buttonTitle: String {
        if !hasClonedProfile {
            return "Setup Debug Mode"
        } else if status == .chromeNotRunning {
            return "Launch Chrome"
        } else {
            return "Restart Chrome"
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .debugModeEnabled:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .debugModeDisabled:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        case .chromeNotRunning:
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    private var statusDescription: String {
        switch status {
        case .debugModeEnabled:
            return "Chrome is ready for Google Meet integration"
        case .debugModeDisabled:
            return "Chrome needs to be restarted with debug mode"
        case .chromeNotRunning:
            if hasClonedProfile {
                return "Launch Chrome with debug mode to enable Google Meet"
            } else {
                return "Click Setup to clone your profile and enable debug mode"
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

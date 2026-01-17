import SwiftUI

@main
struct WhisprMuteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
        }
    }
    @Published var isWisprFlowActive: Bool = false
    @Published var mutedApps: Set<String> = []
    @Published var detectedMeetingApps: [String] = []
    @Published var enabledApps: Set<String> = Set(MeetingAppType.allCases.map { $0.rawValue }) {
        didSet {
            UserDefaults.standard.set(Array(enabledApps), forKey: "enabledApps")
        }
    }

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true
        if let saved = UserDefaults.standard.array(forKey: "enabledApps") as? [String] {
            enabledApps = Set(saved)
        }
    }
}

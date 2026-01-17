import Foundation
import AppKit

class MeetingAppController {
    private let appState: AppState
    private var controllers: [MeetingAppType: MeetingAppControllable] = [:]
    private var previousMuteStates: [MeetingAppType: Bool] = [:]
    private var appsWeMuted: Set<MeetingAppType> = []

    init(appState: AppState) {
        self.appState = appState
        setupControllers()
    }

    private func setupControllers() {
        controllers[.zoom] = ZoomController()
        controllers[.discord] = DiscordController()
        controllers[.slack] = SlackController()
        controllers[.teams] = TeamsController()
        controllers[.googleMeet] = GoogleMeetController()
        controllers[.webex] = WebexController()
        controllers[.skype] = SkypeController()
    }

    func detectRunningMeetingApps() -> [MeetingAppType] {
        return MeetingAppType.allCases.filter { appType in
            guard let controller = controllers[appType] else { return false }
            return controller.isRunning()
        }
    }

    func muteAllMeetingApps() {
        let runningApps = detectRunningMeetingApps()
        print("[MeetingAppController] Running apps: \(runningApps.map { $0.rawValue })")
        appsWeMuted.removeAll()

        for appType in runningApps {
            guard appState.enabledApps.contains(appType.rawValue) else {
                print("[MeetingAppController] \(appType.rawValue) not in enabledApps, skipping")
                continue
            }
            guard let controller = controllers[appType] else {
                print("[MeetingAppController] No controller for \(appType.rawValue)")
                continue
            }

            // Store current mute state if we can detect it
            let currentMuteState = controller.isMuted()
            previousMuteStates[appType] = currentMuteState
            print("[MeetingAppController] \(appType.rawValue) current mute state: \(String(describing: currentMuteState))")

            // Only mute if the app is currently unmuted (or we can't tell)
            if currentMuteState == false || currentMuteState == nil {
                print("[MeetingAppController] Attempting to mute \(appType.rawValue)...")
                let success = controller.mute()
                print("[MeetingAppController] Mute \(appType.rawValue): \(success ? "success" : "failed")")
                if success {
                    appsWeMuted.insert(appType)
                    DispatchQueue.main.async {
                        self.appState.mutedApps.insert(appType.rawValue)
                    }
                }
            }
        }
    }

    func restoreMuteStates() {
        // Only unmute apps that we muted
        for appType in appsWeMuted {
            guard let controller = controllers[appType] else { continue }

            // Get the previous state - only unmute if it was previously unmuted
            let previousState = previousMuteStates[appType]

            // If we couldn't detect state before (nil) or it was unmuted (false), unmute now
            if previousState == nil || previousState == false {
                _ = controller.unmute()
            }

            DispatchQueue.main.async {
                self.appState.mutedApps.remove(appType.rawValue)
            }
        }

        appsWeMuted.removeAll()
        previousMuteStates.removeAll()
    }

    func muteApp(_ appType: MeetingAppType) -> Bool {
        guard let controller = controllers[appType] else { return false }
        return controller.mute()
    }

    func unmuteApp(_ appType: MeetingAppType) -> Bool {
        guard let controller = controllers[appType] else { return false }
        return controller.unmute()
    }

    func isMuted(_ appType: MeetingAppType) -> Bool? {
        guard let controller = controllers[appType] else { return nil }
        return controller.isMuted()
    }
}

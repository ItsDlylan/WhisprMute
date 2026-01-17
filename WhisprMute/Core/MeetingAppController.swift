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
        appsWeMuted.removeAll()

        for appType in runningApps {
            guard appState.enabledApps.contains(appType.rawValue),
                  let controller = controllers[appType] else { continue }

            // Store current mute state if we can detect it
            let currentMuteState = controller.isMuted()
            previousMuteStates[appType] = currentMuteState

            // Only mute if the app is currently unmuted (or we can't tell)
            if currentMuteState == false || currentMuteState == nil {
                if controller.mute() {
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

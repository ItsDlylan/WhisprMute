import Foundation
import AppKit

enum MeetingAppType: String, CaseIterable {
    case zoom = "Zoom"
    case discord = "Discord"
    case slack = "Slack"
    case teams = "Microsoft Teams"
    case googleMeet = "Google Meet"
    case webex = "Webex"
    case skype = "Skype"

    var bundleIdentifier: String {
        switch self {
        case .zoom: return "us.zoom.xos"
        case .discord: return "com.hnc.Discord"
        case .slack: return "com.tinyspeck.slackmacgap"
        case .teams: return "com.microsoft.teams"
        case .googleMeet: return "" // Browser-based
        case .webex: return "com.webex.meetingmanager"
        case .skype: return "com.skype.skype"
        }
    }

    var processNames: [String] {
        switch self {
        case .zoom: return ["zoom.us", "Zoom"]
        case .discord: return ["Discord"]
        case .slack: return ["Slack"]
        case .teams: return ["Microsoft Teams", "Teams"]
        case .googleMeet: return ["Google Chrome", "Safari", "Firefox", "Arc"]
        case .webex: return ["Webex", "Meeting Center"]
        case .skype: return ["Skype"]
        }
    }

    var iconName: String {
        switch self {
        case .zoom: return "video"
        case .discord: return "bubble.left.and.bubble.right"
        case .slack: return "number"
        case .teams: return "person.3"
        case .googleMeet: return "video.badge.checkmark"
        case .webex: return "video.circle"
        case .skype: return "phone"
        }
    }
}

protocol MeetingAppControllable {
    var appType: MeetingAppType { get }

    func isRunning() -> Bool
    func isMuted() -> Bool?
    func mute() -> Bool
    func unmute() -> Bool
}

extension MeetingAppControllable {
    func isRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            if !appType.bundleIdentifier.isEmpty {
                return app.bundleIdentifier == appType.bundleIdentifier
            }
            guard let name = app.localizedName else { return false }
            return appType.processNames.contains { name.contains($0) }
        }
    }

    func runAppleScript(_ script: String) -> Bool {
        guard let appleScript = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
        return error == nil
    }

    func runAppleScriptWithResult(_ script: String) -> String? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }

    func sendKeyboardShortcut(keyCode: UInt16, modifiers: CGEventFlags, to bundleIdentifier: String) -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return false
        }

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = modifiers
        keyUp?.flags = modifiers

        let pid = app.processIdentifier
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)

        return true
    }
}

import Foundation
import AppKit

class WebexController: MeetingAppControllable {
    let appType: MeetingAppType = .webex

    func isMuted() -> Bool? {
        // Webex mute state detection
        let script = """
        tell application "System Events"
            if not (exists process "Webex") then
                return "not_running"
            end if
            tell process "Webex"
                try
                    set allMenuItems to menu items of menu 1 of menu bar item "Meeting" of menu bar 1
                    repeat with mi in allMenuItems
                        set itemName to name of mi
                        if itemName contains "Unmute" then
                            return "muted"
                        else if itemName contains "Mute" and itemName does not contain "Unmute" then
                            return "unmuted"
                        end if
                    end repeat
                end try
            end tell
        end tell
        return "unknown"
        """

        guard let result = runAppleScriptWithResult(script) else { return nil }

        switch result {
        case "muted": return true
        case "unmuted": return false
        default: return nil
        }
    }

    func mute() -> Bool {
        // Webex uses Ctrl+M for mute
        let script = """
        tell application "Webex"
            activate
        end tell
        delay 0.1
        tell application "System Events"
            tell process "Webex"
                keystroke "m" using {control down}
            end tell
        end tell
        """

        return runAppleScript(script)
    }

    func unmute() -> Bool {
        return mute() // Toggle
    }
}

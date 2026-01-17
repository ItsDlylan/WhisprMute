import Foundation
import AppKit

class TeamsController: MeetingAppControllable {
    let appType: MeetingAppType = .teams

    func isMuted() -> Bool? {
        // Teams mute state checking via accessibility
        let script = """
        tell application "System Events"
            if not (exists process "Microsoft Teams") then
                return "not_running"
            end if
            tell process "Microsoft Teams"
                -- Try to find mute button state
                set allWindows to windows
                repeat with w in allWindows
                    try
                        set allButtons to buttons of w
                        repeat with b in allButtons
                            set buttonDesc to description of b
                            if buttonDesc contains "Unmute" then
                                return "muted"
                            else if buttonDesc contains "Mute" then
                                return "unmuted"
                            end if
                        end repeat
                    end try
                end repeat
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
        // Teams uses Cmd+Shift+M for mute toggle during meetings
        let script = """
        tell application "Microsoft Teams"
            activate
        end tell
        delay 0.1
        tell application "System Events"
            tell process "Microsoft Teams"
                keystroke "m" using {command down, shift down}
            end tell
        end tell
        """

        return runAppleScript(script)
    }

    func unmute() -> Bool {
        // Same shortcut toggles mute/unmute
        return mute()
    }
}

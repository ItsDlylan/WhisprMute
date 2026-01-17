import Foundation
import AppKit

class SkypeController: MeetingAppControllable {
    let appType: MeetingAppType = .skype

    func isMuted() -> Bool? {
        // Skype mute state is not easily accessible
        return nil
    }

    func mute() -> Bool {
        // Skype uses Cmd+Shift+M for mute
        let script = """
        tell application "Skype"
            activate
        end tell
        delay 0.1
        tell application "System Events"
            tell process "Skype"
                keystroke "m" using {command down, shift down}
            end tell
        end tell
        """

        return runAppleScript(script)
    }

    func unmute() -> Bool {
        return mute() // Toggle
    }
}

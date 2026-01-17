import Foundation
import AppKit

class SlackController: MeetingAppControllable {
    let appType: MeetingAppType = .slack

    func isMuted() -> Bool? {
        // Slack huddle mute state is not easily accessible
        return nil
    }

    func mute() -> Bool {
        // Slack uses 'M' key to toggle mute in a huddle
        let script = """
        tell application "Slack"
            activate
        end tell
        delay 0.1
        tell application "System Events"
            tell process "Slack"
                keystroke "m"
            end tell
        end tell
        """

        return runAppleScript(script)
    }

    func unmute() -> Bool {
        // Same key toggles mute/unmute
        return mute()
    }
}

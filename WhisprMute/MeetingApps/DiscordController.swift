import Foundation
import AppKit

class DiscordController: MeetingAppControllable {
    let appType: MeetingAppType = .discord

    func isMuted() -> Bool? {
        // Discord doesn't expose mute state via AppleScript easily
        // We'll track it ourselves
        return nil
    }

    func mute() -> Bool {
        // Discord uses Cmd+Shift+M for mute toggle when in a voice channel
        // First, try to activate Discord and send the shortcut

        let script = """
        tell application "Discord"
            activate
        end tell
        delay 0.1
        tell application "System Events"
            tell process "Discord"
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

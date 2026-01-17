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
        // Use System Events AppleScript for more reliable keystroke delivery
        let script = """
        tell application "System Events"
            tell process "Discord"
                keystroke "m" using {command down, shift down}
            end tell
        end tell
        """
        let success = runAppleScript(script)
        print("[DiscordController] mute() via AppleScript: \(success)")
        return success
    }

    func unmute() -> Bool {
        // Same shortcut toggles mute/unmute
        return mute()
    }
}

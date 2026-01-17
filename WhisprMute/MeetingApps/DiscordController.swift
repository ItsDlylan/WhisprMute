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
        // Send keystroke directly to Discord without stealing focus
        return sendKeyboardShortcut(
            keyCode: 0x2E, // 'M' key
            modifiers: [.maskCommand, .maskShift],
            to: appType.bundleIdentifier
        )
    }

    func unmute() -> Bool {
        // Same shortcut toggles mute/unmute
        return mute()
    }
}

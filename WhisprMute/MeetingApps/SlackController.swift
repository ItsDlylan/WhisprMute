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
        // Send keystroke directly without stealing focus
        return sendKeyboardShortcut(
            keyCode: 0x2E, // 'M' key
            modifiers: [],
            to: appType.bundleIdentifier
        )
    }

    func unmute() -> Bool {
        // Same key toggles mute/unmute
        return mute()
    }
}

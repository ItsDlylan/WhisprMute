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
        // Send keystroke directly without stealing focus
        return sendKeyboardShortcut(
            keyCode: 0x2E, // 'M' key
            modifiers: [.maskCommand, .maskShift],
            to: appType.bundleIdentifier
        )
    }

    func unmute() -> Bool {
        return mute() // Toggle
    }
}

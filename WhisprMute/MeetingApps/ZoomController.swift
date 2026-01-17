import Foundation
import AppKit

class ZoomController: MeetingAppControllable {
    let appType: MeetingAppType = .zoom

    func isMuted() -> Bool? {
        let script = """
        tell application "System Events"
            if not (exists process "zoom.us") then
                return "not_running"
            end if
            tell process "zoom.us"
                if exists (menu bar item "Meeting" of menu bar 1) then
                    set meetingMenu to menu 1 of menu bar item "Meeting" of menu bar 1
                    if exists (menu item "Mute Audio" of meetingMenu) then
                        return "unmuted"
                    else if exists (menu item "Unmute Audio" of meetingMenu) then
                        return "muted"
                    end if
                end if
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
        let script = """
        tell application "System Events"
            if exists process "zoom.us" then
                tell process "zoom.us"
                    if exists (menu bar item "Meeting" of menu bar 1) then
                        set meetingMenu to menu 1 of menu bar item "Meeting" of menu bar 1
                        if exists (menu item "Mute Audio" of meetingMenu) then
                            click menu item "Mute Audio" of meetingMenu
                            return true
                        end if
                    end if
                end tell
            end if
        end tell
        return false
        """

        if runAppleScript(script) {
            return true
        }

        // Fallback: send Cmd+Shift+A
        return sendKeyboardShortcut(
            keyCode: 0x00, // 'A' key
            modifiers: [.maskCommand, .maskShift],
            to: appType.bundleIdentifier
        )
    }

    func unmute() -> Bool {
        let script = """
        tell application "System Events"
            if exists process "zoom.us" then
                tell process "zoom.us"
                    if exists (menu bar item "Meeting" of menu bar 1) then
                        set meetingMenu to menu 1 of menu bar item "Meeting" of menu bar 1
                        if exists (menu item "Unmute Audio" of meetingMenu) then
                            click menu item "Unmute Audio" of meetingMenu
                            return true
                        end if
                    end if
                end tell
            end if
        end tell
        return false
        """

        if runAppleScript(script) {
            return true
        }

        return sendKeyboardShortcut(
            keyCode: 0x00,
            modifiers: [.maskCommand, .maskShift],
            to: appType.bundleIdentifier
        )
    }
}

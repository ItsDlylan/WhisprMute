import Foundation
import AppKit

class DiscordController: MeetingAppControllable {
    let appType: MeetingAppType = .discord

    func isMuted() -> Bool? {
        // Discord doesn't expose mute state via AppleScript easily
        return nil
    }

    func mute() -> Bool {
        // Discord uses Cmd+Shift+M for mute toggle when in a voice channel
        // We need to briefly activate Discord to send the keystroke reliably

        guard let discordApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == appType.bundleIdentifier
        }) else {
            print("[DiscordController] Discord not found")
            return false
        }

        // Remember the current frontmost app
        let previousApp = NSWorkspace.shared.frontmostApplication

        // Activate Discord
        discordApp.activate(options: [])

        // Small delay to ensure Discord is active
        usleep(100_000) // 100ms

        // Send Cmd+Shift+M keystroke
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x2E, keyDown: true) // M key
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x2E, keyDown: false)

        keyDown?.flags = [.maskCommand, .maskShift]
        keyUp?.flags = [.maskCommand, .maskShift]

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Small delay before switching back
        usleep(50_000) // 50ms

        // Restore previous app
        if let previousApp = previousApp, previousApp.bundleIdentifier != appType.bundleIdentifier {
            previousApp.activate(options: [])
        }

        print("[DiscordController] mute() sent keystroke to Discord")
        return true
    }

    func unmute() -> Bool {
        // Same shortcut toggles mute/unmute
        return mute()
    }
}

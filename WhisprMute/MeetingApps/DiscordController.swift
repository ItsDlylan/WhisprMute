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

        guard let discordApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == appType.bundleIdentifier
        }) else {
            print("[DiscordController] Discord not found")
            return false
        }

        // Remember the current frontmost app
        let previousApp = NSWorkspace.shared.frontmostApplication
        print("[DiscordController] Previous app: \(previousApp?.localizedName ?? "none")")

        // Activate Discord and wait for it to be frontmost
        discordApp.activate(options: .activateIgnoringOtherApps)

        // Wait for Discord to actually become active
        var attempts = 0
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != appType.bundleIdentifier && attempts < 20 {
            Thread.sleep(forTimeInterval: 0.05)
            attempts += 1
        }
        print("[DiscordController] Discord activated after \(attempts) attempts")

        // Send Cmd+Shift+M keystroke
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x2E, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x2E, keyDown: false) else {
            print("[DiscordController] Failed to create CGEvents")
            return false
        }

        keyDown.flags = [.maskCommand, .maskShift]
        keyUp.flags = [.maskCommand, .maskShift]

        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        keyUp.post(tap: .cghidEventTap)

        print("[DiscordController] Keystroke sent")

        // Wait a moment for the keystroke to be processed
        Thread.sleep(forTimeInterval: 0.1)

        // Restore previous app
        if let previousApp = previousApp, previousApp.bundleIdentifier != appType.bundleIdentifier {
            print("[DiscordController] Restoring: \(previousApp.localizedName ?? "unknown")")
            previousApp.activate(options: .activateIgnoringOtherApps)
        }

        return true
    }

    func unmute() -> Bool {
        // Same shortcut toggles mute/unmute
        return mute()
    }
}

import Foundation
import AppKit
import Carbon.HIToolbox

class DiscordController: MeetingAppControllable {
    let appType: MeetingAppType = .discord

    func isMuted() -> Bool? {
        return nil
    }

    func mute() -> Bool {
        guard let discordApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == appType.bundleIdentifier
        }) else {
            print("[DiscordController] Discord not found")
            return false
        }

        let previousApp = NSWorkspace.shared.frontmostApplication

        // Activate Discord
        discordApp.activate(options: .activateIgnoringOtherApps)

        // Wait for Discord to be frontmost
        Thread.sleep(forTimeInterval: 0.2)

        // Use CGEvent posted to the session (like a real keyboard)
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key code for 'M' is 46 (0x2E)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: false) {

            keyDown.flags = [.maskCommand, .maskShift]
            keyUp.flags = [.maskCommand, .maskShift]

            // Post to the HID event tap - this simulates actual keyboard input
            keyDown.post(tap: .cgSessionEventTap)
            keyUp.post(tap: .cgSessionEventTap)

            print("[DiscordController] Keystroke posted to session")
        }

        // Wait for keystroke to be processed
        Thread.sleep(forTimeInterval: 0.15)

        // Restore previous app
        if let previousApp = previousApp, previousApp.bundleIdentifier != appType.bundleIdentifier {
            previousApp.activate(options: .activateIgnoringOtherApps)
            print("[DiscordController] Restored \(previousApp.localizedName ?? "previous app")")
        }

        return true
    }

    func unmute() -> Bool {
        return mute()
    }
}

import Foundation
import AppKit

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
        let previousPID = previousApp?.processIdentifier
        print("[DiscordController] Previous app: \(previousApp?.localizedName ?? "none") (PID: \(previousPID ?? 0))")

        defer {
            // ALWAYS restore previous app, no matter what
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let pid = previousPID, pid != discordApp.processIdentifier {
                    if let appToRestore = NSRunningApplication(processIdentifier: pid) {
                        print("[DiscordController] Restoring app PID: \(pid)")
                        appToRestore.activate(options: .activateIgnoringOtherApps)
                    }
                }
            }
        }

        // Activate Discord
        discordApp.activate(options: .activateIgnoringOtherApps)
        Thread.sleep(forTimeInterval: 0.15)

        // Send keystroke directly to Discord's PID
        let pid = discordApp.processIdentifier
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x2E, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x2E, keyDown: false) else {
            print("[DiscordController] Failed to create CGEvents")
            return false
        }

        keyDown.flags = [.maskCommand, .maskShift]
        keyUp.flags = [.maskCommand, .maskShift]

        // Post directly to Discord's PID
        keyDown.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.03)
        keyUp.postToPid(pid)

        print("[DiscordController] Keystroke sent to PID \(pid)")
        return true
    }

    func unmute() -> Bool {
        return mute()
    }
}

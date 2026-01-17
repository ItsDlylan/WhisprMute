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

        // Try to find and click the mute button using Accessibility API
        let appElement = AXUIElementCreateApplication(discordApp.processIdentifier)

        if let muteButton = findMuteButton(in: appElement) {
            print("[DiscordController] Found mute button, clicking...")
            AXUIElementPerformAction(muteButton, kAXPressAction as CFString)
            return true
        }

        // Fallback: Activate and send keystroke
        print("[DiscordController] Mute button not found, trying keystroke...")

        discordApp.activate(options: .activateIgnoringOtherApps)
        Thread.sleep(forTimeInterval: 0.2)

        // Simulate Cmd+Shift+M using CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_M), keyDown: false) {

            keyDown.flags = [.maskCommand, .maskShift]
            keyUp.flags = [.maskCommand, .maskShift]

            keyDown.post(tap: .cgSessionEventTap)
            keyUp.post(tap: .cgSessionEventTap)

            print("[DiscordController] Keystroke posted to session")
        }

        Thread.sleep(forTimeInterval: 0.15)

        // Restore previous app
        if let previousApp = previousApp, previousApp.bundleIdentifier != appType.bundleIdentifier {
            previousApp.activate(options: .activateIgnoringOtherApps)
            print("[DiscordController] Restored \(previousApp.localizedName ?? "previous app")")
        }

        return true
    }

    private func findMuteButton(in element: AXUIElement) -> AXUIElement? {
        // Look for mute button by searching for buttons with mute-related descriptions
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else {
            return nil
        }

        for child in childArray {
            // Check if this element is a button
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)

            // Check description/title for mute-related text
            var description: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &description)

            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)

            let desc = (description as? String)?.lowercased() ?? ""
            let titleStr = (title as? String)?.lowercased() ?? ""

            if desc.contains("mute") || titleStr.contains("mute") {
                print("[DiscordController] Found element with mute: \(desc) / \(titleStr)")
                return child
            }

            // Recursively search children
            if let found = findMuteButton(in: child) {
                return found
            }
        }

        return nil
    }

    func unmute() -> Bool {
        return mute()
    }
}

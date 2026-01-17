import Foundation
import AppKit

class DiscordController: MeetingAppControllable {
    let appType: MeetingAppType = .discord

    func isMuted() -> Bool? {
        return nil
    }

    func mute() -> Bool {
        // TODO: Discord muting disabled temporarily - keystroke delivery not working reliably
        // The CGEvent approach isn't reliably sending Cmd+Shift+M to Discord
        // Need to investigate alternative approaches (Discord RPC, accessibility API, etc.)
        print("[DiscordController] mute() - DISABLED (needs fix)")
        return false
    }

    func unmute() -> Bool {
        print("[DiscordController] unmute() - DISABLED (needs fix)")
        return false
    }
}

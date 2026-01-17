import Foundation
import AppKit

class DiscordController: MeetingAppControllable {
    let appType: MeetingAppType = .discord
    private var discordRPC: DiscordRPC?

    func isMuted() -> Bool? {
        return nil
    }

    func mute() -> Bool {
        // Use Discord RPC to mute - no app switching needed
        if discordRPC == nil {
            discordRPC = DiscordRPC()
        }
        return discordRPC?.setMute(true) ?? false
    }

    func unmute() -> Bool {
        return discordRPC?.setMute(false) ?? false
    }
}

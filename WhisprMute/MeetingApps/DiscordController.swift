import Foundation
import AppKit

class DiscordController: MeetingAppControllable {
    let appType: MeetingAppType = .discord
    private var discordRPC: DiscordRPC?

    private func ensureRPC() -> DiscordRPC? {
        if discordRPC == nil {
            discordRPC = DiscordRPC()
        }
        return discordRPC
    }

    func isMuted() -> Bool? {
        return ensureRPC()?.getMuteState()
    }

    func mute() -> Bool {
        return ensureRPC()?.setMute(true) ?? false
    }

    func unmute() -> Bool {
        return ensureRPC()?.setMute(false) ?? false
    }
}

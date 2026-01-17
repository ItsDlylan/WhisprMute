import Foundation
import AppKit

class GoogleMeetController: MeetingAppControllable {
    let appType: MeetingAppType = .googleMeet

    private let browserBundleIds = [
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "company.thebrowser.Browser" // Arc
    ]

    func isRunning() -> Bool {
        // Check if any browser has a Meet tab (approximation - check if browser is running)
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return browserBundleIds.contains(bundleId)
        }
    }

    func isMuted() -> Bool? {
        // Cannot reliably detect Meet mute state from outside the browser
        return nil
    }

    func mute() -> Bool {
        // Google Meet uses Cmd+D for mute toggle
        // Try Chrome first as it's most common
        return muteInChrome() || muteInSafari() || muteInFirefox()
    }

    func unmute() -> Bool {
        return mute() // Toggle
    }

    private func muteInChrome() -> Bool {
        let script = """
        tell application "Google Chrome"
            set meetTab to missing value
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set meetTab to t
                        set active tab index of w to index of t
                        set index of w to 1
                        exit repeat
                    end if
                end repeat
                if meetTab is not missing value then exit repeat
            end repeat

            if meetTab is not missing value then
                activate
                tell application "System Events"
                    keystroke "d" using {command down}
                end tell
                return true
            end if
        end tell
        return false
        """

        return runAppleScript(script)
    }

    private func muteInSafari() -> Bool {
        let script = """
        tell application "Safari"
            set meetTab to missing value
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set meetTab to t
                        set current tab of w to t
                        set index of w to 1
                        exit repeat
                    end if
                end repeat
                if meetTab is not missing value then exit repeat
            end repeat

            if meetTab is not missing value then
                activate
                tell application "System Events"
                    keystroke "d" using {command down}
                end tell
                return true
            end if
        end tell
        return false
        """

        return runAppleScript(script)
    }

    private func muteInFirefox() -> Bool {
        // Firefox doesn't have good AppleScript support for tab manipulation
        // Just try sending the shortcut if Firefox is frontmost or has focus
        let script = """
        tell application "Firefox"
            activate
        end tell
        delay 0.1
        tell application "System Events"
            keystroke "d" using {command down}
        end tell
        """

        return runAppleScript(script)
    }
}

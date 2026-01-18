import Foundation
import AppKit

/// Represents a Chrome profile
struct ChromeProfile: Identifiable, Hashable {
    let id: String          // Folder name (e.g., "Default", "Profile 1")
    let displayName: String // User-friendly name (e.g., "Dylan")

    var isDefault: Bool { id == "Default" }
}

/// Helper for managing Chrome's debug mode for Google Meet integration
class ChromeDebugHelper {
    static let shared = ChromeDebugHelper()
    private let cdpClient = CDPClient()

    /// Path to Chrome's user data directory
    private let chromeUserDataPath = NSHomeDirectory() + "/Library/Application Support/Google/Chrome"

    /// Path to WhisprMute's debug profile directory
    private let debugProfileBasePath = NSHomeDirectory() + "/Library/Application Support/WhisprMute/ChromeDebugProfile"

    private init() {}

    // MARK: - Profile Discovery

    /// Get available Chrome profiles from the Local State file
    func getAvailableProfiles() -> [ChromeProfile] {
        let localStatePath = chromeUserDataPath + "/Local State"

        guard FileManager.default.fileExists(atPath: localStatePath),
              let data = FileManager.default.contents(atPath: localStatePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            print("[ChromeDebugHelper] Could not read Chrome Local State file")
            // Return default profile as fallback
            return [ChromeProfile(id: "Default", displayName: "Default")]
        }

        var profiles: [ChromeProfile] = []

        for (folderName, profileInfo) in infoCache {
            if let info = profileInfo as? [String: Any] {
                let displayName = (info["name"] as? String) ?? folderName
                profiles.append(ChromeProfile(id: folderName, displayName: displayName))
            }
        }

        // Sort with Default first, then alphabetically by display name
        profiles.sort { lhs, rhs in
            if lhs.isDefault { return true }
            if rhs.isDefault { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        print("[ChromeDebugHelper] Found \(profiles.count) Chrome profiles")
        return profiles.isEmpty ? [ChromeProfile(id: "Default", displayName: "Default")] : profiles
    }

    // MARK: - Profile Cloning

    /// Clone essential profile files from source Chrome profile to debug directory
    /// - Parameter profileId: The folder name of the profile to clone (e.g., "Default", "Profile 1")
    /// - Returns: true if cloning was successful
    @discardableResult
    func cloneProfile(profileId: String) -> Bool {
        let sourcePath = chromeUserDataPath + "/" + profileId
        let destPath = debugProfileBasePath + "/Default"  // Always use "Default" in debug profile

        print("[ChromeDebugHelper] Cloning profile '\(profileId)' to debug directory...")

        // Verify source exists
        guard FileManager.default.fileExists(atPath: sourcePath) else {
            print("[ChromeDebugHelper] Source profile not found: \(sourcePath)")
            return false
        }

        // Create destination directory
        do {
            // Remove existing debug profile
            if FileManager.default.fileExists(atPath: debugProfileBasePath) {
                try FileManager.default.removeItem(atPath: debugProfileBasePath)
            }
            try FileManager.default.createDirectory(atPath: destPath, withIntermediateDirectories: true)
        } catch {
            print("[ChromeDebugHelper] Failed to create debug profile directory: \(error)")
            return false
        }

        // Essential files/folders to copy
        let essentialItems = [
            "Preferences",
            "Secure Preferences",
            "Bookmarks",
            "Cookies",
            "Login Data",
            "Web Data",
            "Extensions",
            "Extension State",
            "Local Extension Settings"
        ]

        var copiedCount = 0
        for item in essentialItems {
            let sourceItem = sourcePath + "/" + item
            let destItem = destPath + "/" + item

            if FileManager.default.fileExists(atPath: sourceItem) {
                do {
                    try FileManager.default.copyItem(atPath: sourceItem, toPath: destItem)
                    copiedCount += 1
                    print("[ChromeDebugHelper] Copied: \(item)")
                } catch {
                    print("[ChromeDebugHelper] Failed to copy \(item): \(error)")
                }
            }
        }

        // Also copy Local State to the base directory (needed for Chrome to recognize the profile)
        let localStateSource = chromeUserDataPath + "/Local State"
        let localStateDest = debugProfileBasePath + "/Local State"
        if FileManager.default.fileExists(atPath: localStateSource) {
            do {
                try FileManager.default.copyItem(atPath: localStateSource, toPath: localStateDest)
                print("[ChromeDebugHelper] Copied Local State")
            } catch {
                print("[ChromeDebugHelper] Failed to copy Local State: \(error)")
            }
        }

        print("[ChromeDebugHelper] Profile clone complete. Copied \(copiedCount) items.")
        return copiedCount > 0
    }

    /// Check if a cloned debug profile exists
    func hasClonedProfile() -> Bool {
        let profilePath = debugProfileBasePath + "/Default"
        return FileManager.default.fileExists(atPath: profilePath)
    }

    // MARK: - Chrome Status

    /// Check if Chrome is currently running
    func isChromeRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.google.Chrome" }
    }

    /// Check if Chrome is running with debug port enabled
    func isChromeDebugModeEnabled() -> Bool {
        return cdpClient.isDebugPortAvailable()
    }

    /// Get the current status of Chrome debug mode
    func getStatus() -> ChromeDebugStatus {
        if !isChromeRunning() {
            return .chromeNotRunning
        } else if isChromeDebugModeEnabled() {
            return .debugModeEnabled
        } else {
            return .debugModeDisabled
        }
    }

    /// Restart Chrome with debug mode enabled
    /// - Parameter completion: Called with true if Chrome was successfully restarted
    func restartChromeWithDebugMode(completion: @escaping (Bool) -> Void) {
        print("[ChromeDebugHelper] Starting restart process...")

        // Get list of Chrome URLs before closing
        let urls = getCurrentChromeURLs()
        print("[ChromeDebugHelper] Found \(urls.count) tabs to restore")

        // Close Chrome
        if let chromeApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.google.Chrome" }) {
            print("[ChromeDebugHelper] Terminating Chrome...")
            chromeApp.terminate()

            // Wait for Chrome to close, then relaunch
            DispatchQueue.global().async {
                // Wait up to 5 seconds for Chrome to close
                var attempts = 0
                while self.isChromeRunning() && attempts < 50 {
                    Thread.sleep(forTimeInterval: 0.1)
                    attempts += 1
                }
                print("[ChromeDebugHelper] Chrome closed after \(attempts) attempts")

                // Small delay to ensure clean shutdown
                Thread.sleep(forTimeInterval: 0.5)

                // Relaunch Chrome with debug flag
                DispatchQueue.main.async {
                    self.launchChromeWithDebugMode(restoringURLs: urls, completion: completion)
                }
            }
        } else {
            // Chrome not running, just launch it
            print("[ChromeDebugHelper] Chrome not running, launching fresh")
            launchChromeWithDebugMode(restoringURLs: urls, completion: completion)
        }
    }

    /// Launch Chrome with debug mode (without closing first)
    func launchChromeWithDebugMode(restoringURLs urls: [String] = [], completion: @escaping (Bool) -> Void) {
        let chromeExecutable = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

        // Chrome 136+ requires a separate user data directory for remote debugging
        // We use WhisprMute's cloned profile directory
        let userDataDir = debugProfileBasePath

        // Build the command - launch Chrome directly with the debug flag
        var arguments = [
            "--remote-debugging-port=9222",
            "--user-data-dir=\(userDataDir)"
        ]

        // Add URLs to restore if any
        for url in urls {
            arguments.append(url)
        }

        print("[ChromeDebugHelper] Launching Chrome directly with args: \(arguments)")

        DispatchQueue.global().async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: chromeExecutable)
            task.arguments = arguments

            do {
                try task.run()
                print("[ChromeDebugHelper] Chrome process started")

                // Wait for Chrome to start and debug port to become available
                var success = false
                for attempt in 1...10 {
                    Thread.sleep(forTimeInterval: 0.5)
                    if self.isChromeDebugModeEnabled() {
                        success = true
                        print("[ChromeDebugHelper] Debug port available after \(attempt) attempts")
                        break
                    }
                }

                DispatchQueue.main.async {
                    print("[ChromeDebugHelper] Final debug mode status: \(success)")
                    completion(success)
                }
            } catch {
                print("[ChromeDebugHelper] Failed to launch Chrome: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    /// Get current Chrome tab URLs (for restoration after restart)
    private func getCurrentChromeURLs() -> [String] {
        // Use AppleScript to get URLs from all tabs
        let script = """
        tell application "Google Chrome"
            set urlList to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set end of urlList to URL of t
                end repeat
            end repeat
            return urlList
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return [] }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if error != nil { return [] }

        // Parse the result
        var urls: [String] = []
        let count = result.numberOfItems
        if count > 0 {
            for i in 1...count {
                if let item = result.atIndex(i), let url = item.stringValue {
                    urls.append(url)
                }
            }
        }

        return urls
    }

    enum ChromeDebugStatus {
        case chromeNotRunning
        case debugModeEnabled
        case debugModeDisabled

        var description: String {
            switch self {
            case .chromeNotRunning:
                return "Chrome is not running"
            case .debugModeEnabled:
                return "Debug mode enabled"
            case .debugModeDisabled:
                return "Debug mode not enabled"
            }
        }

        var isReady: Bool {
            return self == .debugModeEnabled
        }
    }
}

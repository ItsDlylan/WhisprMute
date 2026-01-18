import Foundation
import AppKit

/// Helper for managing Chrome's debug mode for Google Meet integration
class ChromeDebugHelper {
    static let shared = ChromeDebugHelper()
    private let cdpClient = CDPClient()

    private init() {}

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

        // Chrome requires a non-default user data directory for remote debugging
        // We'll use the default Chrome profile location which allows it to use existing profile
        let userDataDir = NSHomeDirectory() + "/Library/Application Support/Google/Chrome"

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

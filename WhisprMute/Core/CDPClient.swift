import Foundation

/// Chrome DevTools Protocol client for controlling Chrome tabs without stealing focus
class CDPClient {
    private let debugPort: Int
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageId: Int = 0
    private let session = URLSession.shared

    init(debugPort: Int = 9222) {
        self.debugPort = debugPort
    }

    // MARK: - Tab Discovery

    struct ChromeTab: Codable {
        let id: String
        let title: String
        let url: String
        let webSocketDebuggerUrl: String?
        let type: String
    }

    /// Check if Chrome is running with debug port enabled
    func isDebugPortAvailable() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var available = false

        guard let url = URL(string: "http://localhost:\(debugPort)/json/version") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0

        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                available = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.0)

        return available
    }

    /// List all Chrome tabs
    func listTabs() -> [ChromeTab] {
        let semaphore = DispatchSemaphore(value: 0)
        var tabs: [ChromeTab] = []

        guard let url = URL(string: "http://localhost:\(debugPort)/json") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            guard let data = data else { return }

            do {
                tabs = try JSONDecoder().decode([ChromeTab].self, from: data)
            } catch {
                print("[CDPClient] Failed to decode tabs: \(error)")
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 3.0)

        return tabs
    }

    /// Find Google Meet tab
    func findMeetTab() -> ChromeTab? {
        return listTabs().first { tab in
            tab.url.contains("meet.google.com") && tab.type == "page"
        }
    }

    // MARK: - JavaScript Execution

    /// Execute JavaScript in a tab and return the result
    func executeJavaScript(in tab: ChromeTab, script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        guard let wsUrlString = tab.webSocketDebuggerUrl,
              let wsUrl = URL(string: wsUrlString) else {
            completion(.failure(CDPError.noWebSocketUrl))
            return
        }

        messageId += 1
        let currentMessageId = messageId

        let command: [String: Any] = [
            "id": currentMessageId,
            "method": "Runtime.evaluate",
            "params": [
                "expression": script,
                "returnByValue": true
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: command),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(CDPError.jsonEncodingFailed))
            return
        }

        let webSocketTask = session.webSocketTask(with: wsUrl)
        self.webSocketTask = webSocketTask
        webSocketTask.resume()

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask.send(message) { error in
            if let error = error {
                completion(.failure(error))
                webSocketTask.cancel(with: .goingAway, reason: nil)
                return
            }

            // Receive response
            webSocketTask.receive { result in
                webSocketTask.cancel(with: .goingAway, reason: nil)

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let resultObj = json["result"] as? [String: Any],
                           let innerResult = resultObj["result"] as? [String: Any] {
                            completion(.success(innerResult["value"]))
                        } else {
                            completion(.success(nil))
                        }
                    case .data:
                        completion(.success(nil))
                    @unknown default:
                        completion(.success(nil))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Execute JavaScript synchronously (with timeout)
    func executeJavaScriptSync(in tab: ChromeTab, script: String, timeout: TimeInterval = 5.0) -> Result<Any?, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Any?, Error> = .failure(CDPError.timeout)

        executeJavaScript(in: tab, script: script) { res in
            result = res
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    // MARK: - Google Meet Specific Methods

    /// Check if Google Meet is muted
    func isMeetMuted() -> Bool? {
        guard let tab = findMeetTab() else { return nil }

        // Check for the mute button - if "Turn off microphone" exists, we're unmuted
        // If "Turn on microphone" exists, we're muted
        let script = """
        (function() {
            const muteBtn = document.querySelector('[aria-label*="Turn off microphone"]');
            const unmuteBtn = document.querySelector('[aria-label*="Turn on microphone"]');
            if (muteBtn) return false;  // Unmuted (can turn off)
            if (unmuteBtn) return true; // Muted (can turn on)
            return null;
        })()
        """

        let result = executeJavaScriptSync(in: tab, script: script)
        switch result {
        case .success(let value):
            return value as? Bool
        case .failure:
            return nil
        }
    }

    /// Mute Google Meet (returns true if successful)
    func muteMeet() -> Bool {
        guard let tab = findMeetTab() else {
            print("[CDPClient] No Google Meet tab found")
            return false
        }

        // Click the mute button (Turn off microphone)
        let script = """
        (function() {
            const btn = document.querySelector('[aria-label*="Turn off microphone"]');
            if (btn) {
                btn.click();
                return true;
            }
            // Already muted?
            const unmuteBtn = document.querySelector('[aria-label*="Turn on microphone"]');
            if (unmuteBtn) return true; // Already muted
            return false;
        })()
        """

        let result = executeJavaScriptSync(in: tab, script: script)
        switch result {
        case .success(let value):
            let success = (value as? Bool) ?? false
            print("[CDPClient] Mute Meet result: \(success)")
            return success
        case .failure(let error):
            print("[CDPClient] Mute Meet error: \(error)")
            return false
        }
    }

    /// Unmute Google Meet (returns true if successful)
    func unmuteMeet() -> Bool {
        guard let tab = findMeetTab() else {
            print("[CDPClient] No Google Meet tab found")
            return false
        }

        // Click the unmute button (Turn on microphone)
        let script = """
        (function() {
            const btn = document.querySelector('[aria-label*="Turn on microphone"]');
            if (btn) {
                btn.click();
                return true;
            }
            // Already unmuted?
            const muteBtn = document.querySelector('[aria-label*="Turn off microphone"]');
            if (muteBtn) return true; // Already unmuted
            return false;
        })()
        """

        let result = executeJavaScriptSync(in: tab, script: script)
        switch result {
        case .success(let value):
            let success = (value as? Bool) ?? false
            print("[CDPClient] Unmute Meet result: \(success)")
            return success
        case .failure(let error):
            print("[CDPClient] Unmute Meet error: \(error)")
            return false
        }
    }

    // MARK: - Errors

    enum CDPError: Error {
        case noWebSocketUrl
        case jsonEncodingFailed
        case timeout
        case connectionFailed
    }
}

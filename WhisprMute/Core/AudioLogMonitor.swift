import Foundation
import OSLog
import AppKit

class AudioLogMonitor {
    private var pollingTimer: Timer?
    private var lastMicClientPID: pid_t?
    private var lastMicClientName: String?
    private let logStore: OSLogStore?

    var onMicrophoneClientChanged: ((pid_t?, String?) -> Void)?

    init() {
        do {
            logStore = try OSLogStore(scope: .currentProcessIdentifier)
        } catch {
            logStore = nil
            print("AudioLogMonitor: Failed to create log store: \(error)")
        }
    }

    func startMonitoring() {
        // Poll the system logs frequently to detect mic usage changes
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkCurrentMicrophoneClient()
        }
        checkCurrentMicrophoneClient()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkCurrentMicrophoneClient() {
        let client = getCurrentMicrophoneClient()

        let pidChanged = client?.pid != lastMicClientPID
        let nameChanged = client?.name != lastMicClientName

        if pidChanged || nameChanged {
            lastMicClientPID = client?.pid
            lastMicClientName = client?.name
            onMicrophoneClientChanged?(client?.pid, client?.name)
        }
    }

    func getCurrentMicrophoneClient() -> (pid: pid_t, name: String)? {
        // Try log-based detection first
        if let client = getMicrophoneClientFromLogs() {
            return client
        }

        // Fallback: Check for Wispr Flow using running process info
        return getMicrophoneClientFromProcesses()
    }

    private func getMicrophoneClientFromLogs() -> (pid: pid_t, name: String)? {
        // Use the `log` command to get recent coremedia logs
        // This is more reliable than OSLogStore for system-level logs
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = [
            "show",
            "--predicate", "subsystem == 'com.apple.coremedia'",
            "--style", "compact",
            "--last", "5s"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Parse for PID patterns in coremedia logs
            // macOS 14+: Look for "PID = <number>" or "pid:<number>"
            return parsePIDFromLogOutput(output)
        } catch {
            return nil
        }
    }

    private func parsePIDFromLogOutput(_ output: String) -> (pid: pid_t, name: String)? {
        // Pattern 1: "PID = 12345" (macOS 14+)
        // Pattern 2: "CMIOExtensionPropertyDeviceControlPID = 12345" (macOS 13.3+)
        // Pattern 3: "pid:12345" or "PID:12345"

        let patterns = [
            "PID\\s*=\\s*(\\d+)",
            "CMIOExtensionPropertyDeviceControlPID\\s*=\\s*(\\d+)",
            "pid:(\\d+)",
            "clientPID:(\\d+)",
            "process\\s+(\\d+)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }

            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            let matches = regex.matches(in: output, options: [], range: range)

            // Get the most recent match (last in the output)
            if let lastMatch = matches.last,
               lastMatch.numberOfRanges >= 2,
               let pidRange = Range(lastMatch.range(at: 1), in: output) {
                let pidString = String(output[pidRange])
                if let pid = Int32(pidString), pid > 0 {
                    if let name = resolveProcessName(pid: pid) {
                        return (pid: pid, name: name)
                    }
                }
            }
        }

        return nil
    }

    private func getMicrophoneClientFromProcesses() -> (pid: pid_t, name: String)? {
        // Fallback: Look for known audio capture processes
        // Check if Wispr Flow helper processes are running with audio
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid,command"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Look for Wispr Flow audio processes
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                // Check for Wispr Flow Helper with audio service
                if line.contains("Wispr Flow") &&
                   (line.contains("audio") || line.contains("AudioService") || line.contains("Helper")) {
                    // Extract PID from the beginning of the line
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    let components = trimmed.components(separatedBy: .whitespaces)
                    if let pidString = components.first, let pid = Int32(pidString) {
                        return (pid: pid, name: "Wispr Flow")
                    }
                }
            }
        } catch {
            // Fall through
        }

        return nil
    }

    private func resolveProcessName(pid: pid_t) -> String? {
        // Try NSRunningApplication first
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.localizedName
        }

        // Fallback: Use ps command to get process name
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", "\(pid)", "-o", "comm="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let name = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return name
            }
        } catch {
            // Fall through
        }

        return nil
    }

    deinit {
        stopMonitoring()
    }
}

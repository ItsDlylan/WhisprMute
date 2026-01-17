import Foundation
import AppKit

class AudioLogMonitor {
    private var pollingTimer: Timer?
    private var lastRecordingState: Bool = false

    var onRecordingStateChanged: ((Bool) -> Void)?

    func startMonitoring() {
        // Poll the system logs to detect Wispr Flow recording state changes
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkWisprFlowRecordingState()
        }
        checkWisprFlowRecordingState()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkWisprFlowRecordingState() {
        let isRecording = isWisprFlowCurrentlyRecording()

        if isRecording != lastRecordingState {
            print("[AudioLogMonitor] State changed: \(lastRecordingState) -> \(isRecording)")
            lastRecordingState = isRecording
            DispatchQueue.main.async {
                self.onRecordingStateChanged?(isRecording)
            }
        }
    }

    func isWisprFlowCurrentlyRecording() -> Bool {
        // Query recent logs for Wispr Flow recording state
        // Use a 10-second window to catch state changes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = [
            "show",
            "--predicate", "subsystem == 'com.apple.coremedia' AND composedMessage CONTAINS 'Wispr Flow' AND composedMessage CONTAINS 'Recording'",
            "--style", "compact",
            "--last", "10s"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                // No recent logs - maintain previous state or check if Wispr Flow is even running
                return lastRecordingState && isWisprFlowRunning()
            }

            // Check if we got any actual log entries (not just the header)
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("Timestamp") }
            if lines.isEmpty {
                return lastRecordingState && isWisprFlowRunning()
            }

            // Parse for the LAST recording state
            // Look for patterns like "Recording = YES" or "Recording = NO"
            let result = parseLastRecordingState(from: output)
            return result
        } catch {
            return false
        }
    }

    private func parseLastRecordingState(from output: String) -> Bool {
        // Split into lines and find the last line mentioning Recording state
        let lines = output.components(separatedBy: "\n")

        // Iterate from the end to find the most recent recording state
        for line in lines.reversed() {
            // Skip empty lines
            guard !line.isEmpty else { continue }

            // Look for Wispr Flow with Recording state
            if line.localizedCaseInsensitiveContains("wispr flow") {
                if line.contains("Recording = YES") {
                    return true
                } else if line.contains("Recording = NO") {
                    return false
                } else if line.localizedCaseInsensitiveContains("stopping recording") {
                    return false
                } else if line.localizedCaseInsensitiveContains("starting recording") {
                    return true
                }
            }
        }

        // If we found Wispr Flow logs but no clear state, check for "stopping recording"
        // which indicates recording just ended
        if output.localizedCaseInsensitiveContains("stopping recording") {
            return false
        }

        // No clear state found - maintain previous state
        return lastRecordingState
    }

    private func isWisprFlowRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            guard let name = app.localizedName else { return false }
            return name.localizedCaseInsensitiveContains("Wispr Flow")
        }
    }

    deinit {
        stopMonitoring()
    }
}

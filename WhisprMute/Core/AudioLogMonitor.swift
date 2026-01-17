import Foundation
import AppKit

class AudioLogMonitor {
    private var streamProcess: Process?
    private var lastRecordingState: Bool = false

    var onRecordingStateChanged: ((Bool) -> Void)?

    func startMonitoring() {
        // Use log stream for real-time detection instead of polling
        startLogStream()
    }

    func stopMonitoring() {
        streamProcess?.terminate()
        streamProcess = nil
    }

    private func startLogStream() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = [
            "stream",
            "--predicate", "subsystem == 'com.apple.coremedia' AND composedMessage CONTAINS 'Wispr Flow' AND composedMessage CONTAINS 'Recording'",
            "--style", "compact"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        // Read output asynchronously for real-time processing
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            self?.processLogLine(line)
        }

        do {
            try task.run()
            streamProcess = task
            print("[AudioLogMonitor] Started real-time log stream")
        } catch {
            print("[AudioLogMonitor] Failed to start log stream: \(error)")
        }
    }

    private func processLogLine(_ line: String) {
        // Parse for recording state changes
        guard line.localizedCaseInsensitiveContains("wispr flow") else { return }

        var newState: Bool?

        if line.contains("Recording = YES") {
            newState = true
        } else if line.contains("Recording = NO") {
            newState = false
        } else if line.localizedCaseInsensitiveContains("starting recording") {
            newState = true
        } else if line.localizedCaseInsensitiveContains("stopping recording") {
            newState = false
        }

        guard let isRecording = newState, isRecording != lastRecordingState else { return }

        print("[AudioLogMonitor] State changed: \(lastRecordingState) -> \(isRecording)")
        lastRecordingState = isRecording
        DispatchQueue.main.async {
            self.onRecordingStateChanged?(isRecording)
        }
    }

    deinit {
        stopMonitoring()
    }
}

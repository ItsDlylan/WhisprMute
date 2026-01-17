import Foundation
import AppKit

class WisprFlowDetector {
    private let audioLogMonitor: AudioLogMonitor

    var onWisprFlowStateChanged: ((Bool) -> Void)?

    init() {
        self.audioLogMonitor = AudioLogMonitor()
        setupMonitoring()
    }

    private func setupMonitoring() {
        audioLogMonitor.onRecordingStateChanged = { [weak self] isRecording in
            self?.onWisprFlowStateChanged?(isRecording)
        }
    }

    func startMonitoring() {
        audioLogMonitor.startMonitoring()
    }

    func stopMonitoring() {
        audioLogMonitor.stopMonitoring()
    }

    func isWisprFlowRecording() -> Bool {
        return audioLogMonitor.isCurrentlyRecording
    }

    func isWisprFlowRunning() -> Bool {
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

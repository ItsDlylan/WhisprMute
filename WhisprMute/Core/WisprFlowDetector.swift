import Foundation
import AppKit

class WisprFlowDetector {
    private let audioLogMonitor: AudioLogMonitor
    private var currentMicClientPID: pid_t?
    private var currentMicClientName: String?
    private var lastWisprFlowActive: Bool = false

    var onWisprFlowStateChanged: ((Bool) -> Void)?

    init() {
        self.audioLogMonitor = AudioLogMonitor()
        setupMonitoring()
    }

    private func setupMonitoring() {
        audioLogMonitor.onMicrophoneClientChanged = { [weak self] pid, processName in
            guard let self = self else { return }

            self.currentMicClientPID = pid
            self.currentMicClientName = processName

            let isWisprFlow = self.isWisprFlowProcess(name: processName)

            if isWisprFlow != self.lastWisprFlowActive {
                self.lastWisprFlowActive = isWisprFlow
                DispatchQueue.main.async {
                    self.onWisprFlowStateChanged?(isWisprFlow)
                }
            }
        }
    }

    func startMonitoring() {
        audioLogMonitor.startMonitoring()
    }

    func stopMonitoring() {
        audioLogMonitor.stopMonitoring()
    }

    func isWisprFlowRecording() -> Bool {
        guard let client = audioLogMonitor.getCurrentMicrophoneClient() else {
            return false
        }
        return isWisprFlowProcess(name: client.name)
    }

    private func isWisprFlowProcess(name: String?) -> Bool {
        guard let name = name else { return false }
        return name.localizedCaseInsensitiveContains("Wispr Flow") ||
               name.localizedCaseInsensitiveContains("WisprFlow")
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

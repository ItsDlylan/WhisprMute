import Foundation
import AppKit

class WisprFlowDetector {
    private let microphoneMonitor: MicrophoneMonitor
    private var pollingTimer: Timer?
    private var lastWisprFlowActive: Bool = false

    var onWisprFlowStateChanged: ((Bool) -> Void)?

    private let wisprProcessNames = [
        "Wispr Flow",
        "WisprFlow",
        "wispr",
        "Wispr",
        "flow",
        "Wispr Flow Helper"
    ]

    init(microphoneMonitor: MicrophoneMonitor) {
        self.microphoneMonitor = microphoneMonitor

        microphoneMonitor.onMicrophoneUsageChanged = { [weak self] processes in
            self?.checkForWisprFlow(in: processes)
        }

        startPolling()
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollWisprFlowStatus()
        }
    }

    private func pollWisprFlowStatus() {
        let processes = microphoneMonitor.getProcessesUsingMicrophone()
        checkForWisprFlow(in: processes)
    }

    private func checkForWisprFlow(in processes: [MicrophoneMonitor.MicrophoneProcess]) {
        let wisprFlowActive = processes.contains { process in
            wisprProcessNames.contains { wisprName in
                process.name.localizedCaseInsensitiveContains(wisprName)
            }
        }

        if wisprFlowActive != lastWisprFlowActive {
            lastWisprFlowActive = wisprFlowActive
            onWisprFlowStateChanged?(wisprFlowActive)
        }
    }

    func isWisprFlowRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            guard let name = app.localizedName else { return false }
            return wisprProcessNames.contains { wisprName in
                name.localizedCaseInsensitiveContains(wisprName)
            }
        }
    }

    func isWisprFlowUsingMicrophone() -> Bool {
        let processes = microphoneMonitor.getProcessesUsingMicrophone()
        return processes.contains { process in
            wisprProcessNames.contains { wisprName in
                process.name.localizedCaseInsensitiveContains(wisprName)
            }
        }
    }

    deinit {
        pollingTimer?.invalidate()
    }
}

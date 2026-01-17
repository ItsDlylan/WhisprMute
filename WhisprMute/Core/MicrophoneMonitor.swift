import Foundation
import CoreAudio
import AVFoundation

class MicrophoneMonitor {
    private var pollingTimer: Timer?
    private var lastKnownProcesses: Set<pid_t> = []

    var onMicrophoneUsageChanged: (([MicrophoneProcess]) -> Void)?

    struct MicrophoneProcess: Hashable {
        let pid: pid_t
        let name: String
    }

    func startMonitoring() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkMicrophoneUsage()
        }
        checkMicrophoneUsage()
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkMicrophoneUsage() {
        let processes = getProcessesUsingMicrophone()
        let currentPids = Set(processes.map { $0.pid })

        if currentPids != lastKnownProcesses {
            lastKnownProcesses = currentPids
            onMicrophoneUsageChanged?(processes)
        }
    }

    func getProcessesUsingMicrophone() -> [MicrophoneProcess] {
        var processes: [MicrophoneProcess] = []

        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-c", "/coreaudio/i", "+D", "/dev"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                processes = parseLsofOutput(output)
            }
        } catch {
            processes = getProcessesViaAudioHAL()
        }

        if processes.isEmpty {
            processes = getProcessesViaAudioHAL()
        }

        return processes
    }

    private func parseLsofOutput(_ output: String) -> [MicrophoneProcess] {
        var processes: [MicrophoneProcess] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 2 else { continue }

            let processName = String(components[0])
            if let pid = pid_t(components[1]) {
                if !processes.contains(where: { $0.pid == pid }) {
                    processes.append(MicrophoneProcess(pid: pid, name: processName))
                }
            }
        }

        return processes
    }

    private func getProcessesViaAudioHAL() -> [MicrophoneProcess] {
        var processes: [MicrophoneProcess] = []

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return processes }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &devices
        )

        guard status == noErr else { return processes }

        for device in devices {
            if isInputDevice(device) && isDeviceInUse(device) {
                let tappingProcesses = getProcessesTappingDevice(device)
                processes.append(contentsOf: tappingProcesses)
            }
        }

        return processes
    }

    private func isInputDevice(_ device: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(device, &propertyAddress, 0, nil, &dataSize)

        return status == noErr && dataSize > 0
    }

    private func isDeviceInUse(_ device: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &dataSize, &isRunning)

        return status == noErr && isRunning != 0
    }

    private func getProcessesTappingDevice(_ device: AudioDeviceID) -> [MicrophoneProcess] {
        var processes: [MicrophoneProcess] = []

        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axo", "pid,comm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for line in lines.dropFirst() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    let components = trimmed.split(separator: " ", maxSplits: 1)
                    guard components.count >= 2,
                          let pid = pid_t(components[0]) else { continue }

                    let name = String(components[1])
                    let lowerName = name.lowercased()

                    let audioProcesses = ["wispr", "zoom", "discord", "slack", "teams", "chrome", "firefox", "safari", "webex", "skype"]
                    if audioProcesses.contains(where: { lowerName.contains($0) }) {
                        if !processes.contains(where: { $0.pid == pid }) {
                            processes.append(MicrophoneProcess(pid: pid, name: name))
                        }
                    }
                }
            }
        } catch {
            // Silently fail
        }

        return processes
    }
}

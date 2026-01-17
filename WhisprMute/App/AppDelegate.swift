import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let appState = AppState()

    private var microphoneMonitor: MicrophoneMonitor!
    private var wisprFlowDetector: WisprFlowDetector!
    private var meetingAppController: MeetingAppController!
    private var meetingAppPollingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupServices()
        startMonitoring()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateMenuBarIcon()
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(appState: appState, quitAction: {
            NSApplication.shared.terminate(nil)
        }, openSettingsAction: {
            self.openSettings()
        }))
    }

    private func setupServices() {
        microphoneMonitor = MicrophoneMonitor()
        wisprFlowDetector = WisprFlowDetector(microphoneMonitor: microphoneMonitor)
        meetingAppController = MeetingAppController(appState: appState)

        wisprFlowDetector.onWisprFlowStateChanged = { [weak self] isActive in
            DispatchQueue.main.async {
                self?.handleWisprFlowStateChange(isActive: isActive)
            }
        }
    }

    private func startMonitoring() {
        microphoneMonitor.startMonitoring()

        meetingAppPollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateDetectedMeetingApps()
        }
        updateDetectedMeetingApps()
    }

    private func handleWisprFlowStateChange(isActive: Bool) {
        appState.isWisprFlowActive = isActive
        updateMenuBarIcon()

        guard appState.isEnabled else { return }

        if isActive {
            meetingAppController.muteAllMeetingApps()
        } else {
            meetingAppController.restoreMuteStates()
        }
    }

    private func updateDetectedMeetingApps() {
        let apps = meetingAppController.detectRunningMeetingApps()
        DispatchQueue.main.async {
            self.appState.detectedMeetingApps = apps.map { $0.rawValue }
        }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let iconName: String
        if !appState.isEnabled {
            iconName = "mic.slash"
        } else if appState.isWisprFlowActive {
            iconName = "mic.fill"
        } else {
            iconName = "mic"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "WhisprMute") {
            button.image = image.withSymbolConfiguration(config)
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func openSettings() {
        popover.performClose(nil)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        meetingAppPollingTimer?.invalidate()
        microphoneMonitor.stopMonitoring()

        if appState.isWisprFlowActive {
            meetingAppController.restoreMuteStates()
        }
    }
}

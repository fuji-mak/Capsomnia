import AppKit
import CoreGraphics
import Foundation

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var didRequestDisplaySleepForClosedLid = false
    private var hasLoggedMissingClamshellState = false
    private var shouldRestoreSleepOnTerminate = true
    private var eventTap: CFMachPort?
    private var pollingTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private let onImage = DotImage.make(color: brandLEDColor)
    private let offImage = DotImage.make(color: NSColor(calibratedWhite: 0.58, alpha: 1.0))

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfNewerInteractiveDuplicate() {
            return
        }

        Preferences.registerDefaults()
        Preferences.migrateInputMonitoringPreferenceIfNeeded()
        let shouldShowInitialSetup = Preferences.consumeForceWelcomeOnNextLaunch()
            || !Preferences.didCompleteInitialSetup

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOpenSettingsNotification),
            name: openSettingsNotificationName,
            object: appLabel
        )

        NSApp.setActivationPolicy(.accessory)
        syncStatusItemVisibility()
        installSignalHandlers()
        installPollingMonitor()
        log("start")
        applyCurrentCapsLockState(reason: "startup")

        if shouldShowInitialSetup {
            showSettingsWindow(page: initialSetupPage())
        } else if Preferences.inputMonitoringRequested {
            installEventTap()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow(page: currentSettingsPage())
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard shouldRestoreSleepOnTerminate else { return }

        let shouldReopen = consumeInputMonitoringReopenRequest()
        if shouldReopen {
            scheduleReopenAfterTermination()
        }

        log("terminate restore_off\(shouldReopen ? " reopen_after_permission_quit" : "")")
        _ = runHelper("off")
    }

    private func terminateIfNewerInteractiveDuplicate() -> Bool {
        guard ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] != appLabel else {
            return false
        }

        let currentPID = getpid()
        let olderInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: appLabel)
            .filter { !$0.isTerminated && $0.processIdentifier > 0 && $0.processIdentifier < currentPID }

        guard let existing = olderInstances.min(by: { $0.processIdentifier < $1.processIdentifier }) else {
            return false
        }

        shouldRestoreSleepOnTerminate = false
        DistributedNotificationCenter.default().post(
            name: openSettingsNotificationName,
            object: appLabel,
            userInfo: nil
        )
        existing.activate(options: [])
        log("duplicate_instance existing_pid=\(existing.processIdentifier) terminate_without_restore")
        NSApp.terminate(nil)
        return true
    }

    @objc private func handleOpenSettingsNotification(_ notification: Notification) {
        showSettingsWindow(page: currentSettingsPage())
    }

    private func syncStatusItemVisibility() {
        if Preferences.showMenuBarIcon {
            if statusItem == nil {
                installStatusItem()
            }

            let capsLockOn = lastAppliedState
                ?? CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
            updateStatus(capsLockOn: capsLockOn)
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 24)
        statusItem = item

        if let button = item.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.toolTip = appName
        }

        rebuildStatusMenu()
        updateStatus(capsLockOn: false)
    }

    private func rebuildStatusMenu() {
        guard let item = statusItem else { return }

        let strings = AppStrings.current()
        let menu = NSMenu()
        let showMenuBarItem = NSMenuItem(
            title: strings.showMenuBarIcon,
            action: #selector(toggleShowMenuBarIcon),
            keyEquivalent: ""
        )
        showMenuBarItem.target = self
        showMenuBarItem.state = Preferences.showMenuBarIcon ? .on : .off
        menu.addItem(showMenuBarItem)

        let languageItem = NSMenuItem(title: strings.language, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: strings.language)
        for language in AppLanguage.allCases {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(selectLanguage),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = Preferences.language == language ? .on : .off
            languageMenu.addItem(item)
        }
        menu.setSubmenu(languageMenu, for: languageItem)
        menu.addItem(languageItem)

        let openItem = NSMenuItem(title: strings.openCapsomnia, action: #selector(openCapsomnia), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: strings.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func toggleShowMenuBarIcon() {
        setShowMenuBarIcon(!Preferences.showMenuBarIcon)
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else {
            return
        }

        setLanguage(language)
    }

    @objc private func openCapsomnia() {
        showSettingsWindow(page: currentSettingsPage())
    }

    @objc private func quit() {
        log("menu_quit")
        NSApp.terminate(nil)
    }

    private func showSettingsWindow(page: SettingsPage) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                onShowMenuBarIconChange: { [weak self] enabled in
                    self?.setShowMenuBarIcon(enabled)
                },
                onLanguageChange: { [weak self] language in
                    self?.setLanguage(language)
                },
                onLaunchAtLoginChange: { [weak self] enabled in
                    self?.setLaunchAtLogin(enabled)
                },
                onDisplaySleepOnLidCloseChange: { [weak self] enabled in
                    self?.setDisplaySleepOnLidClose(enabled)
                },
                onOpenInputMonitoring: { [weak self] in
                    self?.openInputMonitoring()
                },
                onFinishInitialSetup: { [weak self] in
                    Preferences.ensureInputMonitoringChoiceRecorded()
                    Preferences.didCompleteInitialSetup = true
                    if Preferences.inputMonitoringRequested {
                        self?.installEventTap()
                    }
                }
            )
        }

        settingsWindowController?.show(page: page)
    }

    private func currentSettingsPage() -> SettingsPage {
        Preferences.didCompleteInitialSetup ? .settings : initialSetupPage()
    }

    private func initialSetupPage() -> SettingsPage {
        CGPreflightListenEventAccess() ? .initialPreferences : .permissions
    }

    private func setShowMenuBarIcon(_ enabled: Bool) {
        Preferences.showMenuBarIcon = enabled
        syncStatusItemVisibility()
        rebuildStatusMenu()
        log("preference show_menu_bar_icon=\(enabled ? "on" : "off")")
    }

    private func setLanguage(_ language: AppLanguage) {
        guard Preferences.language != language else { return }
        Preferences.language = language
        rebuildStatusMenu()

        let capsLockOn = lastAppliedState
            ?? CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        updateStatus(capsLockOn: capsLockOn)
        settingsWindowController?.reloadText()
        log("preference language=\(language.rawValue)")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAgentManager.setEnabled(enabled)
            Preferences.launchAtLogin = enabled
            rebuildStatusMenu()
            log("preference launch_at_login=\(enabled ? "on" : "off")")
        } catch {
            rebuildStatusMenu()
            log("preference launch_at_login_error=\(error.localizedDescription)")
        }
    }

    private func setDisplaySleepOnLidClose(_ enabled: Bool) {
        Preferences.displaySleepOnLidClose = enabled
        if enabled {
            let capsLockOn = lastAppliedState
                ?? CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
            evaluateDisplaySleepForClosedLid(capsLockOn: capsLockOn, reason: "preference")
        } else {
            didRequestDisplaySleepForClosedLid = false
        }
        log("preference display_sleep_on_lid_close=\(enabled ? "on" : "off")")
    }

    private func openInputMonitoring() {
        Preferences.showWelcomeOnNextLaunch()
        Preferences.inputMonitoringRequested = true
        Preferences.markInputMonitoringReopenPending()
        installEventTap()
        openInputMonitoringSettings()
        log("open_input_monitoring_settings")
    }

    private func consumeInputMonitoringReopenRequest() -> Bool {
        let shouldReopen = Preferences.consumeFreshInputMonitoringReopenRequest()
        if shouldReopen {
            Preferences.showWelcomeOnNextLaunch()
        }
        return shouldReopen
    }

    private func scheduleReopenAfterTermination() {
        let bundlePath = Bundle.main.bundleURL.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep 1; /usr/bin/open \"$1\"",
            "capsomnia-reopen",
            bundlePath
        ]

        do {
            try process.run()
            log("scheduled_reopen_after_permission_quit")
        } catch {
            log("schedule_reopen_failed error=\(error.localizedDescription)")
        }
    }

    private func openInputMonitoringSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_ListenEvent"
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    private func installEventTap() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            log("event_tap_unavailable using_polling_fallback")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("event_tap_ready")
    }

    private func installPollingMonitor() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.applyCurrentCapsLockState(reason: "poll")
        }
    }

    fileprivate func handleFlagsChanged(_ event: CGEvent) {
        let capsLockOn = event.flags.contains(.maskAlphaShift)
        DispatchQueue.main.async { [weak self] in
            self?.apply(capsLockOn: capsLockOn, reason: "flagsChanged")
        }
    }

    fileprivate func reenableEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            log("event_tap_reenabled")
        }
    }

    private func applyCurrentCapsLockState(reason: String) {
        let flags = CGEventSource.flagsState(.hidSystemState)
        apply(capsLockOn: flags.contains(.maskAlphaShift), reason: reason)
    }

    private func apply(capsLockOn: Bool, reason: String) {
        guard lastAppliedState != capsLockOn else {
            evaluateDisplaySleepForClosedLid(capsLockOn: capsLockOn, reason: reason)
            return
        }

        lastAppliedState = capsLockOn
        let mode = capsLockOn ? "on" : "off"
        let result = runHelper(mode)
        updateStatus(capsLockOn: capsLockOn)
        log("\(reason) capslock=\(mode) helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
        evaluateDisplaySleepForClosedLid(capsLockOn: capsLockOn, reason: reason)
    }

    private func evaluateDisplaySleepForClosedLid(capsLockOn: Bool, reason: String) {
        guard Preferences.displaySleepOnLidClose else {
            didRequestDisplaySleepForClosedLid = false
            return
        }

        guard capsLockOn else {
            didRequestDisplaySleepForClosedLid = false
            return
        }

        guard let clamshellClosed = ClamshellStateReader.isClosed() else {
            didRequestDisplaySleepForClosedLid = false
            if !hasLoggedMissingClamshellState {
                log("\(reason) clamshell_state_unavailable")
                hasLoggedMissingClamshellState = true
            }
            return
        }
        hasLoggedMissingClamshellState = false

        guard clamshellClosed else {
            didRequestDisplaySleepForClosedLid = false
            return
        }

        guard !didRequestDisplaySleepForClosedLid else { return }
        didRequestDisplaySleepForClosedLid = true

        let result = runHelper(displaySleepHelperMode)
        log("\(reason) clamshell=closed display_sleep_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
    }

    private func updateStatus(capsLockOn: Bool) {
        guard let button = statusItem?.button else { return }
        let strings = AppStrings.current()
        button.image = capsLockOn ? onImage : offImage
        button.toolTip = capsLockOn ? strings.tooltipOn : strings.tooltipOff
    }

    private func runHelper(_ mode: String) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath, mode]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
            return (
                process.terminationStatus,
                read(stdoutPipe.fileHandleForReading),
                read(stderrPipe.fileHandleForReading)
            )
        } catch {
            return (-1, "", "\(error)")
        }
    }

    private func read(_ handle: FileHandle) -> String {
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        for signalNumber in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                let shouldReopen = self?.consumeInputMonitoringReopenRequest() ?? false
                if shouldReopen {
                    self?.scheduleReopenAfterTermination()
                }
                self?.log("signal=\(signalNumber) restore_off\(shouldReopen ? " reopen_after_permission_quit" : "")")
                _ = self?.runHelper("off")
                exit(shouldReopen ? 1 : 0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        let url = URL(fileURLWithPath: logPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logPath),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

private nonisolated(unsafe) let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let app = Unmanaged<Capsomnia>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    switch type {
    case .flagsChanged:
        app.handleFlagsChanged(event)
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        app.reenableEventTap()
    default:
        break
    }

    return Unmanaged.passUnretained(event)
}

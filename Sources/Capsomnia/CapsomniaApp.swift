import AppKit
import CoreGraphics
import Foundation

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var sleepStateSelection = SleepStateSelection()
    private var failedSleepState: Bool?
    private var nextSleepStateRetryAt = Date.distantPast
    private var nextSleepStateVerificationAt = Date.distantPast
    private var nextDisplaySleepRetryAt = Date.distantPast
    private var didRequestDisplaySleepForClosedLid = false
    private var hasLoggedMissingClamshellState = false
    private var hasLoggedMissingDisplayState = false
    private var hasLoggedMissingSleepState = false
    private var hasTouchedCapsLockLED = false
    private var shouldRestoreSleepOnTerminate = true
    private var pollingTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private let onImage = DotImage.make(color: Brand.led)
    private let offImage = DotImage.make(color: NSColor(calibratedWhite: 0.58, alpha: 1.0))
    private let errorImage = DotImage.make(color: .systemRed)
    private let helperRetryInterval: TimeInterval = 5
    private let sleepStateVerificationInterval: TimeInterval = 10
    private lazy var capsLockLEDController = CapsLockLEDController { [weak self] message in
        // HID writes run on their own serial queue. Bring diagnostics back to
        // the main queue so the existing file logger is never used concurrently.
        DispatchQueue.main.async {
            self?.log(message)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfNewerInteractiveDuplicate() {
            return
        }

        Preferences.registerDefaults()
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
            showSettingsWindow(page: .initialPreferences)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow(page: currentSettingsPage())
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard shouldRestoreSleepOnTerminate else { return }

        restoreCapsLockLEDBeforeExit(reason: "terminate")
        let result = runHelper("off")
        log("terminate restore_off helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
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

    /// The state Capsomnia is acting on. A menu choice takes precedence while
    /// present; the existing applied/live fallbacks preserve startup behavior.
    private var currentCapsLockState: Bool {
        sleepStateSelection.desiredState
            ?? lastAppliedState
            ?? CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
    }

    private func syncStatusItemVisibility() {
        if Preferences.showMenuBarIcon {
            if statusItem == nil {
                installStatusItem()
            }

            refreshStatus(capsLockOn: currentCapsLockState)
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
        let preventSleepItem = NSMenuItem(
            title: strings.preventSleep,
            action: #selector(toggleSleepPrevention),
            keyEquivalent: ""
        )
        preventSleepItem.target = self
        preventSleepItem.state = currentCapsLockState ? .on : .off
        menu.addItem(preventSleepItem)
        menu.addItem(NSMenuItem.separator())

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

    @objc private func toggleSleepPrevention(_ sender: NSMenuItem) {
        // Observe the live modifier at click time so a physical transition just
        // before opening the menu wins over the previous 250 ms poll result.
        let hardwareState = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        let currentState = sleepStateSelection.observeHardwareState(hardwareState).sleepPreventionOn
        let enabled = !currentState
        sleepStateSelection.setManualOverride(enabled)
        sender.state = enabled ? .on : .off
        refreshStatus(capsLockOn: enabled)
        log("menu manual_sleep_prevention=\(enabled ? "on" : "off")")

        // `pmset` is intentionally deferred by one main-loop turn. The existing
        // synchronous helper remains unchanged, but the menu can close before it
        // runs instead of appearing stuck while the subprocess finishes.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.apply(capsLockOn: enabled, reason: "menu")

            // `apply` can legitimately take its already-confirmed fast path.
            // Synchronize here as well as after confirmation so that path still
            // gets the physical indicator requested by the menu action.
            self.synchronizeManualCapsLockLED(capsLockOn: enabled, reason: "menu")
        }
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
                onFinishInitialSetup: { [weak self] in
                    Preferences.didCompleteInitialSetup = true
                    self?.log("initial_setup_complete")
                }
            )
        }

        settingsWindowController?.show(page: page)
    }

    private func currentSettingsPage() -> SettingsPage {
        Preferences.didCompleteInitialSetup ? .settings : .initialPreferences
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

        refreshStatus(capsLockOn: currentCapsLockState)
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
            evaluateDisplaySleepForClosedLid(capsLockOn: currentCapsLockState, reason: "preference")
        } else {
            didRequestDisplaySleepForClosedLid = false
        }
        log("preference display_sleep_on_lid_close=\(enabled ? "on" : "off")")
    }

    private func installPollingMonitor() {
        pollingTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.applyCurrentCapsLockState(reason: "poll")
        }
        timer.tolerance = 0.05
        pollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        log("polling_ready interval_ms=250 tolerance_ms=50")
    }

    private func applyCurrentCapsLockState(reason: String) {
        let flags = CGEventSource.flagsState(.hidSystemState)
        let hardwareState = flags.contains(.maskAlphaShift)
        let resolution = sleepStateSelection.observeHardwareState(hardwareState)
        // The menu checkmark mirrors both the original physical switch and a
        // manual override. Assigning the existing item is cheaper than rebuilding
        // the localized menu on every 250 ms poll.
        statusItem?.menu?.items
            .first(where: { $0.action == #selector(toggleSleepPrevention) })?
            .state = resolution.sleepPreventionOn ? .on : .off
        if resolution.clearedManualOverride {
            log("\(reason) hardware_capslock_changed manual_override=cleared")
            restoreAutomaticCapsLockLED(reason: reason)
        }
        apply(capsLockOn: resolution.sleepPreventionOn, reason: reason)
    }

    private func apply(capsLockOn: Bool, reason: String) {
        let now = Date()
        if failedSleepState == capsLockOn, now < nextSleepStateRetryAt {
            return
        }

        if lastAppliedState == capsLockOn {
            if failedSleepState == nil, now < nextSleepStateVerificationAt {
                evaluateDisplaySleepForClosedLid(capsLockOn: capsLockOn, reason: reason)
                return
            }

            guard let actualState = SleepStateReader.isDisabled() else {
                if !hasLoggedMissingSleepState {
                    log("\(reason) sleep_state_unavailable")
                    hasLoggedMissingSleepState = true
                }
                markSleepStateFailed(capsLockOn, at: now)
                return
            }

            hasLoggedMissingSleepState = false
            if actualState == capsLockOn {
                markSleepStateConfirmed(capsLockOn, at: now, reason: reason)
                return
            }

            log("\(reason) sleep_state_drift expected=\(capsLockOn ? "on" : "off") actual=\(actualState ? "on" : "off")")
        }

        let mode = capsLockOn ? "on" : "off"
        let result = runHelper(mode)
        log("\(reason) capslock=\(mode) helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")

        guard result.status == 0 else {
            markSleepStateFailed(capsLockOn, at: now, resetVerification: false)
            return
        }

        lastAppliedState = capsLockOn
        let confirmedState = SleepStateReader.isDisabled()
        guard confirmedState == Optional(capsLockOn) else {
            hasLoggedMissingSleepState = confirmedState == nil
            log("\(reason) sleep_state_confirmation_failed expected=\(mode) actual=\(confirmedState.map { $0 ? "on" : "off" } ?? "unknown")")
            markSleepStateFailed(capsLockOn, at: now)
            return
        }

        markSleepStateConfirmed(capsLockOn, at: now, reason: reason)
    }

    private func markSleepStateFailed(_ capsLockOn: Bool, at now: Date, resetVerification: Bool = true) {
        failedSleepState = capsLockOn
        nextSleepStateRetryAt = now.addingTimeInterval(helperRetryInterval)
        if resetVerification {
            nextSleepStateVerificationAt = nextSleepStateRetryAt
        }
        updateStatusError()
    }

    private func markSleepStateConfirmed(_ capsLockOn: Bool, at now: Date, reason: String) {
        hasLoggedMissingSleepState = false
        failedSleepState = nil
        nextSleepStateRetryAt = .distantPast
        nextSleepStateVerificationAt = now.addingTimeInterval(sleepStateVerificationInterval)
        syncStatusItemVisibility()
        synchronizeManualCapsLockLED(capsLockOn: capsLockOn, reason: reason)
        evaluateDisplaySleepForClosedLid(capsLockOn: capsLockOn, reason: reason)
    }

    private func synchronizeManualCapsLockLED(capsLockOn: Bool, reason: String) {
        // The LED must not claim that sleep prevention is active until the
        // helper result is confirmed. A failed or superseded menu request keeps
        // the software error state without publishing a misleading light.
        guard sleepStateSelection.manualOverride == Optional(capsLockOn),
              failedSleepState == nil,
              lastAppliedState == capsLockOn else {
            return
        }

        hasTouchedCapsLockLED = true
        capsLockLEDController.synchronize(enabled: capsLockOn, reason: reason)
    }

    private func restoreAutomaticCapsLockLED(reason: String) {
        guard hasTouchedCapsLockLED else { return }

        // A real Caps Lock transition ends the menu override. Auto hands the
        // shared event-system property back instead of pinning the sampled state.
        capsLockLEDController.restoreAutomatic(reason: "\(reason)_manual_override_cleared")
    }

    private func restoreCapsLockLEDBeforeExit(reason: String) {
        guard hasTouchedCapsLockLED else { return }

        // Stop and drain maintenance before Auto; otherwise a queued repair could
        // win after cleanup and leave the indicator pinned after Capsomnia exits.
        capsLockLEDController.restoreAutomaticImmediately(reason: reason)
        hasTouchedCapsLockLED = false
    }

    private func evaluateDisplaySleepForClosedLid(capsLockOn: Bool, reason: String) {
        guard Preferences.displaySleepOnLidClose else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            return
        }

        guard capsLockOn else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
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
            nextDisplaySleepRetryAt = .distantPast
            return
        }

        let externalDisplayConnected = ExternalDisplayReader.isConnected()
        if externalDisplayConnected != nil {
            hasLoggedMissingDisplayState = false
        }
        guard DisplaySleepPolicy.shouldRequestDisplaySleep(
            externalDisplayConnected: externalDisplayConnected
        ) else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            if externalDisplayConnected == nil, !hasLoggedMissingDisplayState {
                log("\(reason) external_display_state_unavailable")
                hasLoggedMissingDisplayState = true
            }
            return
        }

        guard !didRequestDisplaySleepForClosedLid else { return }
        let now = Date()
        guard now >= nextDisplaySleepRetryAt else { return }

        let result = runHelper(displaySleepHelperMode)
        log("\(reason) clamshell=closed display_sleep_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
        if result.status == 0 {
            didRequestDisplaySleepForClosedLid = true
            nextDisplaySleepRetryAt = .distantPast
        } else {
            nextDisplaySleepRetryAt = now.addingTimeInterval(helperRetryInterval)
        }
    }

    private func updateStatus(capsLockOn: Bool) {
        guard let button = statusItem?.button else { return }
        let strings = AppStrings.current()
        button.image = capsLockOn ? onImage : offImage
        button.toolTip = capsLockOn ? strings.tooltipOn : strings.tooltipOff
    }

    private func refreshStatus(capsLockOn: Bool) {
        if failedSleepState == nil {
            updateStatus(capsLockOn: capsLockOn)
        } else {
            updateStatusError()
        }
    }

    private func updateStatusError() {
        if statusItem == nil {
            installStatusItem()
        }
        guard let button = statusItem?.button else { return }
        button.image = errorImage
        button.toolTip = AppStrings.current().tooltipError
    }

    private func runHelper(_ mode: String) -> (status: Int32, stdout: String, stderr: String) {
        CommandRunner.run("/usr/bin/sudo", ["-n", helperPath, mode])
    }

    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        for signalNumber in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                self?.restoreCapsLockLEDBeforeExit(reason: "signal_\(signalNumber)")
                let result = self?.runHelper("off")
                self?.log(
                    "signal=\(signalNumber) restore_off helper_status=\(result?.status ?? -1) "
                        + "stdout=\(result?.stdout ?? "") stderr=\(result?.stderr ?? "")"
                )
                exit(0)
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

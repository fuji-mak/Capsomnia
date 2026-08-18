import AppKit
import Carbon.HIToolbox
import Foundation

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var failedSleepState: Bool?
    private var nextSleepStateRetryAt = Date.distantPast
    private var nextSleepStateVerificationAt = Date.distantPast
    private var nextDisplaySleepRetryAt = Date.distantPast
    private var autoOffState = AutoOffState()
    private var isAutoOffToggleInFlight = false
    private var didRequestDisplaySleepForClosedLid = false
    private var hasLoggedMissingClamshellState = false
    private var hasLoggedMissingCapsLockState = false
    private var hasLoggedMissingDisplayState = false
    private var hasLoggedMissingSleepState = false
    private var dedicatedModeError = false
    private var shouldRestoreSleepOnTerminate = true
    private var pollingTimer: Timer?
    private var pendingCapsLockOffWorkItem: DispatchWorkItem?
    private var pendingInputSourceRecoveryWorkItem: DispatchWorkItem?
    private var pendingAutoOffPreferenceApplyWorkItem: DispatchWorkItem?
    private var globalCapsLockEventMonitor: Any?
    private var localCapsLockEventMonitor: Any?
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private let onImage = DotImage.make(color: Brand.led)
    private let offImage = DotImage.make(color: NSColor(calibratedWhite: 0.58, alpha: 1.0))
    private let errorImage = DotImage.make(color: .systemRed)
    private let capsLockStateReader = SystemCapsLockStateReader()
    private let dedicatedCapsLockFilter = DedicatedCapsLockFilter()
    private let capsLockToggleCoordinator = CapsLockToggleCoordinator()
    private let autoOffSleepCoordinator = AutoOffSleepCoordinator()
    private let globalHotKeyManager = GlobalHotKeyManager()
    private var nextDedicatedModeRetryAt = Date.distantPast
    private let helperRetryInterval: TimeInterval = 5
    private let dedicatedModeRetryInterval: TimeInterval = 5
    private let sleepStateVerificationInterval: TimeInterval = 10
    private let capsLockOffDebounceInterval: TimeInterval = 0.35
    private let inputSourceNotificationDebounceInterval: TimeInterval = 0.1
    private let inputSourceInternalNotificationSuppression: TimeInterval = 0.5
    private let userCapsLockEventSuppressionInterval: TimeInterval = 0.5
    // Longer than the input-source suppression window: the external-off guard
    // consults this after the 350 ms off-debounce and possible polling delay,
    // so an intentional turn-off must stay recognizable for a few seconds.
    private let userActionExternalGuardBypassInterval: TimeInterval = 3
    private var suppressInputSourceNotificationsUntil = Date.distantPast
    private var suppressInputSourceRecoveryUntil = Date.distantPast
    private var externalCapsLockOffGuardBypassUntil = Date.distantPast
    private let selectedKeyboardInputSourceChangedNotificationName = Notification.Name(
        kTISNotifySelectedKeyboardInputSourceChanged as String
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfNewerInteractiveDuplicate() {
            return
        }

        Preferences.registerDefaults()
        configureGlobalHotKey()
        let shouldShowInitialSetup = Preferences.consumeForceWelcomeOnNextLaunch()
            || !Preferences.didCompleteInitialSetup

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOpenSettingsNotification),
            name: openSettingsNotificationName,
            object: appLabel
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSelectedKeyboardInputSourceChanged),
            name: selectedKeyboardInputSourceChangedNotificationName,
            object: nil
        )

        NSApp.setActivationPolicy(.accessory)
        syncStatusItemVisibility()
        installCapsLockEventMonitors()
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
        dedicatedCapsLockFilter.stop()
        if let globalCapsLockEventMonitor {
            NSEvent.removeMonitor(globalCapsLockEventMonitor)
        }
        if let localCapsLockEventMonitor {
            NSEvent.removeMonitor(localCapsLockEventMonitor)
        }
        globalCapsLockEventMonitor = nil
        localCapsLockEventMonitor = nil
        pendingCapsLockOffWorkItem?.cancel()
        pendingCapsLockOffWorkItem = nil
        pendingInputSourceRecoveryWorkItem?.cancel()
        pendingInputSourceRecoveryWorkItem = nil
        pendingAutoOffPreferenceApplyWorkItem?.cancel()
        pendingAutoOffPreferenceApplyWorkItem = nil
        DistributedNotificationCenter.default().removeObserver(self)
        guard shouldRestoreSleepOnTerminate else { return }

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

    @objc private func handleSelectedKeyboardInputSourceChanged(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleSelectedKeyboardInputSourceChanged(notification)
            }
            return
        }

        let now = Date()
        guard now >= suppressInputSourceNotificationsUntil,
              now >= suppressInputSourceRecoveryUntil,
              lastAppliedState == true else { return }

        cancelPendingCapsLockOff()
        if pendingInputSourceRecoveryWorkItem == nil {
            log("input_source_changed recovery_scheduled")
        }
        scheduleInputSourceRecovery()
    }

    private func installCapsLockEventMonitors() {
        let capsLockKeyCode = UInt16(kVK_CapsLock)
        globalCapsLockEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            guard event.keyCode == capsLockKeyCode else { return }
            DispatchQueue.main.async {
                self?.handleUserCapsLockKeyEvent()
            }
        }
        localCapsLockEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            if event.keyCode == capsLockKeyCode {
                self?.handleUserCapsLockKeyEvent()
            }
            return event
        }
        log(
            "capslock_key_monitor global=\(globalCapsLockEventMonitor != nil ? "active" : "unavailable")"
        )
    }

    private func handleUserCapsLockKeyEvent() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleUserCapsLockKeyEvent()
            }
            return
        }

        suppressInputSourceRecoveryForUserAction(reason: "capslock_key")
    }

    private func suppressInputSourceRecoveryForUserAction(reason: String) {
        cancelInputSourceRecovery()
        suppressInputSourceRecoveryUntil = Date().addingTimeInterval(
            userCapsLockEventSuppressionInterval
        )
        externalCapsLockOffGuardBypassUntil = Date().addingTimeInterval(
            userActionExternalGuardBypassInterval
        )
        log("\(reason) user_action input_source_recovery_suppressed")
    }

    private func scheduleInputSourceRecovery() {
        pendingInputSourceRecoveryWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingInputSourceRecoveryWorkItem = nil
            self.reassertCapsLockAfterInputSourceChange(reason: "input_source_changed")
        }
        pendingInputSourceRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + inputSourceNotificationDebounceInterval,
            execute: workItem
        )
    }

    private func reassertCapsLockAfterInputSourceChange(reason: String) {
        guard lastAppliedState == true else { return }

        guard let capsLockOn = capsLockStateReader.currentState() else {
            log("\(reason) capslock_state_unavailable recovery_pending")
            updateStatusError()
            return
        }

        guard !capsLockOn else {
            refreshStatus(capsLockOn: true)
            return
        }

        suppressInputSourceNotificationsUntil = Date().addingTimeInterval(
            inputSourceInternalNotificationSuppression
        )
        let result = SystemCapsLockController.set(true)
        log("\(reason) reassert_capslock result=\(String(describing: result))")
        guard result == .changed(to: true) else {
            updateStatusError()
            return
        }

        apply(capsLockOn: true, reason: "\(reason)_reasserted")
    }

    private func cancelInputSourceRecovery() {
        cancelPendingCapsLockOff()
        pendingInputSourceRecoveryWorkItem?.cancel()
        pendingInputSourceRecoveryWorkItem = nil
        suppressInputSourceNotificationsUntil = .distantPast
    }

    private func cancelPendingCapsLockOff() {
        pendingCapsLockOffWorkItem?.cancel()
        pendingCapsLockOffWorkItem = nil
    }

    /// The live Caps Lock state used for the status indicator, falling back
    /// to the last applied sleep state only when the hardware state is
    /// temporarily unavailable.
    private var currentCapsLockState: Bool {
        capsLockStateReader.currentState() ?? lastAppliedState ?? false
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

        log("status_item installed visible=\(item.isVisible) length=\(item.length) button=\(item.button != nil)")

        rebuildStatusMenu()
        updateStatus(capsLockOn: false)
    }

    private func rebuildStatusMenu() {
        guard let item = statusItem else { return }

        let strings = AppStrings.current()
        let menu = NSMenu()
        let toggleCapsLockItem = NSMenuItem(
            title: strings.toggleCapsLock,
            action: #selector(toggleCapsLockFromMenu),
            keyEquivalent: ""
        )
        toggleCapsLockItem.target = self
        menu.addItem(toggleCapsLockItem)
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

    @objc private func toggleShowMenuBarIcon() {
        setShowMenuBarIcon(!Preferences.showMenuBarIcon)
    }

    @objc private func toggleCapsLockFromMenu() {
        // NSMenu tracks in a non-default run loop mode. Scheduling in the
        // default mode lets the action return and menu tracking finish before
        // changing the real modifier-lock state.
        RunLoop.main.perform(inModes: [.default]) { [weak self] in
            self?.requestCapsLockToggle(source: "menu")
        }
    }

    private func requestCapsLockToggle(source: String) {
        suppressInputSourceRecoveryForUserAction(reason: source)
        log("\(source)_toggle_capslock requested")
        capsLockToggleCoordinator.requestToggle { [weak self] result in
            self?.handleCapsLockToggleResult(result, source: source)
        }
    }

    private func handleCapsLockToggleResult(
        _ result: CapsLockToggleResult,
        source: String
    ) {
        switch result {
        case let .changed(target):
            cancelInputSourceRecovery()
            log("\(source)_toggle_capslock target=\(target ? "on" : "off") succeeded=true")
        case .unavailable:
            log("\(source)_toggle_capslock failed=hid_system_unavailable")
        case .readFailed:
            log("\(source)_toggle_capslock failed=read_state")
        case let .writeFailed(target):
            log("\(source)_toggle_capslock target=\(target ? "on" : "off") failed=write_state")
        case let .verificationFailed(target, actual):
            let actualValue = actual.map { $0 ? "on" : "off" } ?? "unknown"
            log(
                "\(source)_toggle_capslock target=\(target ? "on" : "off")"
                    + " failed=verification actual=\(actualValue)"
            )
        }
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
                onDedicatedCapsLockModeChange: { [weak self] enabled in
                    self?.setDedicatedCapsLockMode(enabled)
                },
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
                onIgnoreExternalCapsLockOffWhileLidClosedChange: { [weak self] enabled in
                    self?.setIgnoreExternalCapsLockOffWhileLidClosed(enabled)
                },
                onHideCapsLockIndicatorChange: { [weak self] hidden in
                    self?.setHideCapsLockIndicator(hidden)
                },
                capsLockIndicatorStateProvider: { [weak self] in
                    self?.capsLockIndicatorDisplayState()
                        ?? CapsLockIndicatorDisplayState(hidden: false, restartPending: false)
                },
                onAutoOffMinutesChange: { [weak self] minutes in
                    self?.setAutoOffMinutes(minutes)
                },
                onAutoOffRestart: { [weak self] in
                    self?.restartAutoOff()
                },
                autoOffDisplayProvider: { [weak self] in
                    self?.autoOffDisplayState() ?? .idle(minutes: 0)
                },
                onKeyboardShortcutChange: { [weak self] shortcut in
                    self?.setKeyboardShortcut(shortcut) ?? false
                },
                onKeyboardShortcutRecordingChange: { [weak self] isRecording in
                    self?.setKeyboardShortcutRecording(isRecording)
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
        settingsWindowController?.reloadText()
        log("preference show_menu_bar_icon=\(enabled ? "on" : "off")")
    }

    private func setDedicatedCapsLockMode(_ enabled: Bool) {
        Preferences.dedicatedCapsLockMode = enabled
        nextDedicatedModeRetryAt = .distantPast

        if !enabled {
            dedicatedCapsLockFilter.stop()
            dedicatedModeError = false
        }

        let ready = ensureDedicatedCapsLockFilter(
            promptForPermission: enabled,
            reason: "preference"
        )
        syncStatusItemVisibility()
        rebuildStatusMenu()
        applyCurrentCapsLockState(reason: "preference")
        settingsWindowController?.reloadText()
        log(
            "preference dedicated_caps_lock_mode=\(enabled ? "on" : "off")"
                + " filter_ready=\(ready ? "yes" : "no")"
        )
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

    private func setIgnoreExternalCapsLockOffWhileLidClosed(_ enabled: Bool) {
        Preferences.ignoreExternalCapsLockOffWhileLidClosed = enabled
        log("preference ignore_external_capslock_off_while_lid_closed=\(enabled ? "on" : "off")")
    }

    /// The indicator toggle reflects the on-disk feature-flag override, so a
    /// failed helper call simply leaves the toggle on its previous state when
    /// the window reloads.
    private func setHideCapsLockIndicator(_ hidden: Bool) {
        let result = runHelper(hidden ? indicatorHideHelperMode : indicatorShowHelperMode)
        log(
            "preference hide_caps_lock_indicator=\(hidden ? "on" : "off")"
                + " helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)"
        )
        settingsWindowController?.reloadText()
    }

    private func capsLockIndicatorDisplayState() -> CapsLockIndicatorDisplayState {
        let hidden = CapsLockIndicatorFeatureFlag.isHidden()
        let evaluation = CapsLockIndicatorRestartPolicy.evaluate(
            snapshot: Preferences.capsLockIndicatorBootSnapshot,
            currentBootTime: SystemBootTimeReader.bootTime(),
            currentHidden: hidden
        )
        if evaluation.snapshot != Preferences.capsLockIndicatorBootSnapshot {
            Preferences.capsLockIndicatorBootSnapshot = evaluation.snapshot
        }
        return CapsLockIndicatorDisplayState(
            hidden: hidden,
            restartPending: evaluation.restartPending
        )
    }

    /// Advance the auto-off timer and, if it has elapsed, turn awake mode off.
    /// Returns `true` when an auto-off was triggered this call.
    @discardableResult
    private func evaluateAutoOff(capsLockOn: Bool, reason: String) -> Bool {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: capsLockOn,
            autoOffMinutes: Preferences.autoOffMinutes,
            now: Date(),
            state: autoOffState
        )
        autoOffState = result.state
        let didFire = result.shouldFire
        if didFire {
            fireAutoOff(reason: reason)
        }
        return didFire
    }

    private func fireAutoOff(reason: String) {
        guard !isAutoOffToggleInFlight else { return }
        isAutoOffToggleInFlight = true
        // Prevent input-source-change recovery from re-asserting Caps Lock and
        // undoing the auto-off while the off is being applied.
        suppressInputSourceRecoveryForUserAction(reason: "auto_off")
        autoOffState = AutoOffState()
        log("auto_off elapsed reason=\(reason)")
        capsLockToggleCoordinator.requestSet(false) { [weak self] result in
            guard let self else { return }
            self.isAutoOffToggleInFlight = false
            self.autoOffSleepCoordinator.recordCapsLockResult(result)
            self.handleCapsLockToggleResult(result, source: "auto_off")
            self.applyCurrentCapsLockState(reason: "auto_off")
        }
    }

    private func setAutoOffMinutes(_ minutes: Int) {
        Preferences.autoOffMinutes = minutes
        // Start fresh with the newly chosen duration.
        autoOffState = AutoOffState()
        log("preference auto_off_minutes=\(minutes)")

        // Let AppKit paint the selected value before querying pmset/helper state,
        // and coalesce rapid +/- clicks so only the final value is re-applied.
        pendingAutoOffPreferenceApplyWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingAutoOffPreferenceApplyWorkItem = nil
            self.applyCurrentCapsLockState(reason: "preference")
        }
        pendingAutoOffPreferenceApplyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func restartAutoOff() {
        let minutes = Preferences.autoOffMinutes
        guard minutes > 0 else { return }
        autoOffState = AutoOffPolicy.restarted(
            capsLockOn: currentCapsLockState,
            autoOffMinutes: minutes,
            now: Date()
        )
        log("auto_off restart minutes=\(minutes)")
        applyCurrentCapsLockState(reason: "restart")
    }

    private func autoOffDisplayState() -> AutoOffDisplayState {
        let minutes = Preferences.autoOffMinutes
        guard currentCapsLockState else {
            return .idle(minutes: minutes)
        }
        guard minutes > 0 else {
            return .infinite
        }
        if let deadline = autoOffState.deadline {
            return .counting(remaining: max(0, deadline.timeIntervalSinceNow))
        }
        return .counting(remaining: TimeInterval(minutes) * 60)
    }

    private func configureGlobalHotKey() {
        globalHotKeyManager.onTrigger = { [weak self] in
            self?.requestCapsLockToggle(source: "shortcut")
        }

        let shortcut = Preferences.keyboardShortcut
        let status = globalHotKeyManager.replaceShortcut(with: shortcut)
        guard status == noErr else {
            Preferences.keyboardShortcut = nil
            log("shortcut_register startup_failed status=\(status)")
            return
        }

        if let shortcut {
            log("shortcut_register startup=\(shortcut.displayValue) succeeded=true")
        }
    }

    private func setKeyboardShortcut(_ shortcut: KeyboardShortcut?) -> Bool {
        let status = globalHotKeyManager.replaceShortcut(with: shortcut)
        guard status == noErr else {
            log(
                "shortcut_register value=\(shortcut?.displayValue ?? "none")"
                    + " failed_status=\(status)"
            )
            return false
        }

        Preferences.keyboardShortcut = shortcut
        log("preference keyboard_shortcut=\(shortcut?.displayValue ?? "none")")
        return true
    }

    private func setKeyboardShortcutRecording(_ isRecording: Bool) {
        if isRecording {
            globalHotKeyManager.suspend()
            return
        }

        let status = globalHotKeyManager.replaceShortcut(
            with: Preferences.keyboardShortcut
        )
        guard status != noErr else { return }

        Preferences.keyboardShortcut = nil
        settingsWindowController?.reloadText()
        log("shortcut_register resume_failed status=\(status)")
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
        // While an auto-off toggle is being applied on the background queue,
        // pause state application; the toggle's completion re-syncs afterward.
        if isAutoOffToggleInFlight {
            return
        }

        let filterReady = ensureDedicatedCapsLockFilter(
            promptForPermission: false,
            reason: reason
        )
        guard DedicatedCapsLockReadinessPolicy.shouldHonorCapsLock(
            dedicatedModeEnabled: Preferences.dedicatedCapsLockMode,
            filterActive: filterReady
        ) else {
            _ = evaluateAutoOff(capsLockOn: false, reason: "\(reason)_dedicated_fail_closed")
            apply(capsLockOn: false, reason: "\(reason)_dedicated_fail_closed")
            updateStatusError()
            return
        }

        guard let capsLockOn = capsLockStateReader.currentState() else {
            if pendingInputSourceRecoveryWorkItem != nil {
                return
            }
            if !hasLoggedMissingCapsLockState {
                log("\(reason) capslock_state_unavailable")
                hasLoggedMissingCapsLockState = true
            }
            _ = evaluateAutoOff(capsLockOn: false, reason: "\(reason)_capslock_unavailable")
            apply(capsLockOn: false, reason: "\(reason)_capslock_unavailable")
            updateStatusError()
            return
        }

        hasLoggedMissingCapsLockState = false
        if pendingInputSourceRecoveryWorkItem != nil, lastAppliedState == true {
            return
        }

        if lastAppliedState == true, !capsLockOn {
            if ExternalCapsLockOffPolicy.shouldReassert(
                preferenceEnabled: Preferences.ignoreExternalCapsLockOffWhileLidClosed,
                sleepPreventionActive: true,
                recentUserAction: Date() < externalCapsLockOffGuardBypassUntil,
                autoOffInProgress: isAutoOffToggleInFlight || autoOffSleepCoordinator.isPending,
                clamshellClosed: ClamshellStateReader.isClosed()
            ) {
                reassertCapsLockAfterExternalOff(reason: reason)
                return
            }
            scheduleCapsLockOff(reason: reason)
            return
        }

        cancelPendingCapsLockOff()
        if evaluateAutoOff(capsLockOn: capsLockOn, reason: reason) {
            // Auto-off fired: the toggle-off is now applying asynchronously.
            return
        }
        apply(capsLockOn: capsLockOn, reason: reason)
    }

    /// Re-assert Caps Lock after an external turn-off while the lid is
    /// closed. Falls back to the normal turn-off path when the re-assert
    /// fails, so a persistent failure can never wedge the app in a loop.
    private func reassertCapsLockAfterExternalOff(reason: String) {
        let result = SystemCapsLockController.set(true)
        log(
            "\(reason) external_capslock_off clamshell=closed"
                + " reassert result=\(String(describing: result))"
        )
        guard result == .changed(to: true) else {
            scheduleCapsLockOff(reason: reason)
            return
        }

        apply(capsLockOn: true, reason: "\(reason)_external_off_reasserted")
    }

    private func scheduleCapsLockOff(reason: String) {
        guard pendingCapsLockOffWorkItem == nil else { return }

        log("\(reason) capslock=off debounce_ms=350")

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingCapsLockOffWorkItem = nil

            guard self.capsLockStateReader.currentState() == false else {
                return
            }

            if self.pendingInputSourceRecoveryWorkItem != nil,
               self.lastAppliedState == true {
                return
            }

            _ = self.evaluateAutoOff(capsLockOn: false, reason: "\(reason)_debounced")
            self.apply(capsLockOn: false, reason: "\(reason)_debounced")
        }

        pendingCapsLockOffWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + capsLockOffDebounceInterval,
            execute: workItem
        )
    }

    private func ensureDedicatedCapsLockFilter(
        promptForPermission: Bool,
        reason: String
    ) -> Bool {
        guard Preferences.dedicatedCapsLockMode else {
            if dedicatedCapsLockFilter.state != .inactive {
                dedicatedCapsLockFilter.stop()
            }
            dedicatedModeError = false
            nextDedicatedModeRetryAt = .distantPast
            return true
        }

        if dedicatedCapsLockFilter.isActive {
            dedicatedModeError = false
            nextDedicatedModeRetryAt = .distantPast
            return true
        }

        let now = Date()
        guard promptForPermission || now >= nextDedicatedModeRetryAt else {
            dedicatedModeError = true
            return false
        }

        let state = dedicatedCapsLockFilter.start(
            promptForPermission: promptForPermission
        )
        let isReady = state == .active
        dedicatedModeError = !isReady
        nextDedicatedModeRetryAt = isReady
            ? .distantPast
            : now.addingTimeInterval(dedicatedModeRetryInterval)
        log("\(reason) dedicated_caps_lock_filter=\(String(describing: state))")
        return isReady
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
        evaluateDisplaySleepForClosedLid(capsLockOn: capsLockOn, reason: reason)
        requestSystemSleepAfterAutoOffIfReady(capsLockOn: capsLockOn, reason: reason)
    }

    private func requestSystemSleepAfterAutoOffIfReady(capsLockOn: Bool, reason: String) {
        let wasPending = autoOffSleepCoordinator.isPending
        if wasPending, capsLockOn {
            log("\(reason) auto_off_sleep canceled=capslock_on")
        } else if wasPending {
            log("\(reason) auto_off_sleep requested")
        }

        guard let result = autoOffSleepCoordinator.requestSleepIfReady(
            capsLockOn: capsLockOn
        ) else {
            return
        }

        log(
            "\(reason) auto_off_sleep status=\(result.status)"
                + " stdout=\(result.stdout) stderr=\(result.stderr)"
        )
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
        if failedSleepState == nil, !dedicatedModeError {
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
        let strings = AppStrings.current()
        button.toolTip = dedicatedModeError
            ? strings.tooltipDedicatedPermission
            : strings.tooltipError
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
                self?.dedicatedCapsLockFilter.stop()
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

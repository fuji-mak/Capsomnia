import AppKit
import CapsomniaIntegrationKit
import Foundation

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var failedSleepState: Bool?
    private var nextSleepStateRetryAt = Date.distantPast
    private var nextDisplaySleepRetryAt = Date.distantPast
    private var didRequestDisplaySleepForClosedLid = false
    private var observedClamshellClosed = false
    private var hasLoggedMissingClamshellState = false
    private var hasLoggedMissingSleepState = false
    private var shouldRestoreSleepOnTerminate = true
    private var sleepVerificationTimer: Timer?
    private var sleepRetryTimer: Timer?
    private var clamshellPollingTimer: Timer?
    private var displaySleepRetryTimer: Timer?
    private var autoSleepCountdownTimer: Timer?
    private var automaticSleepRecoveryTimer: Timer?
    private var autoSleepDeadline: Date?
    private var isPreparingAutomaticSleep = false
    private var lastAgentEventID: String?
    private var signalSources: [DispatchSourceSignal] = []
    private var instanceLock: SingleInstanceLock?
    private var statusItem: NSStatusItem?
    private var statusMenuController: StatusMenuController?
    private let onImage = DotImage.makeRing(color: NSColor(calibratedWhite: 0.60, alpha: 1.0))
    private let offImage = DotImage.makeFilled(color: NSColor(calibratedWhite: 0.60, alpha: 1.0))
    private let errorImage = DotImage.makeFilled(color: .systemRed)
    private let helperRetryInterval: TimeInterval = 5
    private let sleepStateVerificationInterval: TimeInterval = 60
    private let clamshellPollingInterval: TimeInterval = 5
    private let automaticSleepDelay: TimeInterval = 30
    private let automaticSleepRecoveryInterval: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfDuplicate() {
            return
        }

        Preferences.registerDefaults()
        synchronizeLaunchAtLoginPreference()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOpenMenuNotification),
            name: openMenuNotificationName,
            object: appLabel
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAgentTaskFinishedNotification),
            name: Notification.Name(AIIntegrationManager.completionNotificationName),
            object: AIIntegrationManager.appLabel
        )

        NSApp.setActivationPolicy(.accessory)
        ensureStatusItem()
        installSignalHandlers()
        installWorkspaceObservers()
        installMonitoring()
        if Preferences.autoSleepAfterAgentTask {
            synchronizeAIIntegrations(reason: "startup")
        } else {
            removeAIIntegrations(reason: "startup_disabled")
        }
        log("start")
        applyCurrentControlState(reason: "startup")

    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.button?.performClick(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard shouldRestoreSleepOnTerminate else { return }

        let result = runHelper("off")
        log("terminate restore_off helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
    }

    private func terminateIfDuplicate() -> Bool {
        let currentPID = getpid()
        let existingInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: appLabel)
            .filter { !$0.isTerminated && $0.processIdentifier > 0 && $0.processIdentifier != currentPID }

        if let existing = existingInstances.first {
            notifyExistingInstanceAndTerminate(existing)
            return true
        }

        do {
            let lockDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Capsomnia", isDirectory: true)
            try FileManager.default.createDirectory(
                at: lockDirectory,
                withIntermediateDirectories: true
            )
            let lockPath = lockDirectory.appendingPathComponent("instance.lock").path
            guard let lock = try SingleInstanceLock.acquire(atPath: lockPath) else {
                notifyExistingInstanceAndTerminate(nil)
                return true
            }
            instanceLock = lock
            return false
        } catch {
            log("single_instance_lock_error=\(error.localizedDescription)")
            notifyExistingInstanceAndTerminate(nil)
            return true
        }
    }

    private func notifyExistingInstanceAndTerminate(_ existing: NSRunningApplication?) {
        shouldRestoreSleepOnTerminate = false
        DistributedNotificationCenter.default().post(
            name: openMenuNotificationName,
            object: appLabel,
            userInfo: nil
        )
        existing?.activate(options: [])
        log("duplicate_instance existing_pid=\(existing?.processIdentifier ?? -1) terminate_without_restore")
        // A launchd-managed duplicate must exit as a temporary failure so the
        // agent retries after the older process has completely disappeared.
        exit(75)
    }

    @objc private func handleOpenMenuNotification(_ notification: Notification) {
        statusItem?.button?.performClick(nil)
    }

    private func ensureStatusItem() {
        if statusItem == nil {
            installStatusItem()
        }

        let isKeepRunning = lastAppliedState ?? Preferences.enabled
        refreshStatus(isKeepRunning: isKeepRunning)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        let menuController = StatusMenuController(
            onEnabledChange: { [weak self] enabled in
                self?.setEnabled(enabled)
            },
            onAutoSleepAfterAgentTaskChange: { [weak self] enabled in
                self?.setAutoSleepAfterAgentTask(enabled)
            },
            onDisplaySleepChange: { [weak self] enabled in
                self?.setDisplaySleepOnLidClose(enabled)
            },
            onLaunchAtLoginChange: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            onLanguageChange: { [weak self] language in
                self?.setLanguage(language)
            },
            onCancelPendingAutoSleep: { [weak self] in
                self?.cancelPendingAutomaticSleep(reason: "menu")
            },
            onMenuOpen: { [weak self] in
                guard Preferences.autoSleepAfterAgentTask else { return }
                self?.synchronizeAIIntegrations(reason: "menu_open")
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        statusMenuController = menuController
        item.menu = menuController.menu

        if let button = item.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.contentTintColor = nil
            button.appearsDisabled = false
        }

        updateStatus(isKeepRunning: false)
    }

    private func setEnabled(_ enabled: Bool) {
        Preferences.enabled = enabled
        if !enabled {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            observedClamshellClosed = false
            displaySleepRetryTimer?.invalidate()
            displaySleepRetryTimer = nil
        }
        applyCurrentControlState(reason: "preference_enabled")
        updateSleepVerificationTimer()
        updateClamshellPolling()
        statusMenuController?.refreshControls()
        log("preference enabled=\(enabled ? "on" : "off")")
    }

    private func setLanguage(_ language: AppLanguage) {
        guard Preferences.language != language else { return }
        Preferences.language = language

        let isKeepRunning = lastAppliedState ?? Preferences.enabled
        refreshStatus(isKeepRunning: isKeepRunning)
        statusMenuController?.reloadText()
        log("preference language=\(language.rawValue)")
    }

    private func setAutoSleepAfterAgentTask(_ enabled: Bool) {
        Preferences.autoSleepAfterAgentTask = enabled
        if enabled {
            synchronizeAIIntegrations(reason: "preference_enabled")
        } else {
            cancelPendingAutomaticSleep(reason: "preference_disabled")
            if !removeAIIntegrations(reason: "preference_disabled") {
                Preferences.autoSleepAfterAgentTask = true
            }
        }
        statusMenuController?.refreshControls()
        log("preference auto_sleep_after_agent_task=\(enabled ? "on" : "off")")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAgentManager.setEnabled(enabled)
            Preferences.launchAtLogin = LaunchAgentManager.isEnabled() ?? enabled
            log("preference launch_at_login=\(enabled ? "on" : "off")")
        } catch {
            synchronizeLaunchAtLoginPreference()
            log("preference launch_at_login_error=\(error.localizedDescription)")
        }
        statusMenuController?.refreshControls()
    }

    private func synchronizeLaunchAtLoginPreference() {
        guard let isEnabled = LaunchAgentManager.isEnabled() else {
            log("launch_at_login_state_unavailable")
            return
        }
        Preferences.launchAtLogin = isEnabled
    }

    private func setDisplaySleepOnLidClose(_ enabled: Bool) {
        Preferences.displaySleepOnLidClose = enabled
        if enabled {
            observedClamshellClosed = false
            updateClamshellPolling()
            let isKeepRunning = lastAppliedState ?? Preferences.enabled
            evaluateDisplaySleepForClosedLid(isKeepRunning: isKeepRunning, reason: "preference")
        } else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            observedClamshellClosed = false
            displaySleepRetryTimer?.invalidate()
            displaySleepRetryTimer = nil
            updateClamshellPolling()
        }
        statusMenuController?.refreshControls()
        log("preference display_sleep_on_lid_close=\(enabled ? "on" : "off")")
    }

    private func installMonitoring() {
        updateSleepVerificationTimer()
        updateClamshellPolling()
        log("monitoring_ready sleep_verification_seconds=60 clamshell_poll_seconds=5")
    }

    private func updateSleepVerificationTimer() {
        guard Preferences.enabled, !isPreparingAutomaticSleep else {
            sleepVerificationTimer?.invalidate()
            sleepVerificationTimer = nil
            return
        }
        guard sleepVerificationTimer == nil else { return }

        sleepVerificationTimer?.invalidate()
        let timer = Timer(timeInterval: sleepStateVerificationInterval, repeats: true) { [weak self] _ in
            self?.apply(reason: "verification", forceVerification: true)
        }
        timer.tolerance = 5
        sleepVerificationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateClamshellPolling() {
        let shouldPoll = Preferences.enabled
            && Preferences.displaySleepOnLidClose
            && !observedClamshellClosed

        guard shouldPoll else {
            clamshellPollingTimer?.invalidate()
            clamshellPollingTimer = nil
            return
        }
        guard clamshellPollingTimer == nil else { return }

        let timer = Timer(timeInterval: clamshellPollingInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let isKeepRunning = self.lastAppliedState ?? Preferences.enabled
            self.evaluateDisplaySleepForClosedLid(isKeepRunning: isKeepRunning, reason: "clamshell_poll")
        }
        timer.tolerance = 0.25
        clamshellPollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func installWorkspaceObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleScreensDidWake(_ notification: Notification) {
        observedClamshellClosed = false
        nextDisplaySleepRetryAt = .distantPast
        displaySleepRetryTimer?.invalidate()
        displaySleepRetryTimer = nil
        updateClamshellPolling()
        if Preferences.enabled {
            apply(reason: "screens_woke", forceVerification: true)
        }
    }

    @objc private func handleSystemDidWake(_ notification: Notification) {
        guard isPreparingAutomaticSleep else { return }
        finishAutomaticSleepCycle(reason: "system_wake")
    }

    private func synchronizeAIIntegrations(reason: String) {
        guard Preferences.autoSleepAfterAgentTask else {
            log("\(reason) ai_integrations skipped=preference_disabled")
            return
        }
        guard canUsePrivilegedHelper() else {
            log("\(reason) ai_integrations skipped=helper_not_authorized")
            return
        }
        let bridgeURL = AIIntegrationManager.bridgeURL(in: Bundle.main.bundleURL)
        guard FileManager.default.isExecutableFile(atPath: bridgeURL.path) else {
            log("\(reason) ai_integration_bridge_missing path=\(bridgeURL.path)")
            return
        }

        let status = AIIntegrationManager(bridgeExecutableURL: bridgeURL).ensureInstalled()
        log(
            "\(reason) ai_integrations codex_detected=\(status.codexDetected) "
                + "codex_configured=\(status.codexConfigured) "
                + "claude_detected=\(status.claudeDetected) "
                + "claude_configured=\(status.claudeConfigured) "
                + "errors=\(status.errors.joined(separator: " | "))"
        )
    }

    @discardableResult
    private func removeAIIntegrations(reason: String) -> Bool {
        let bridgeURL = AIIntegrationManager.bridgeURL(in: Bundle.main.bundleURL)
        guard FileManager.default.isExecutableFile(atPath: bridgeURL.path) else {
            log("\(reason) ai_integration_bridge_missing path=\(bridgeURL.path)")
            return false
        }
        let errors = AIIntegrationManager(bridgeExecutableURL: bridgeURL).removeInstalledIntegrations()
        log("\(reason) ai_integrations_removed errors=\(errors.joined(separator: " | "))")
        return errors.isEmpty
    }

    private func canUsePrivilegedHelper() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "-l", helperPath, "on"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @objc private func handleAgentTaskFinishedNotification(_ notification: Notification) {
        guard Preferences.autoSleepAfterAgentTask else {
            log("ai_task_finished ignored=preference_disabled")
            return
        }

        let source = notification.userInfo?["source"] as? String ?? "unknown"
        let eventID = notification.userInfo?["eventID"] as? String
        if let eventID, eventID == lastAgentEventID {
            log("ai_task_finished ignored=duplicate source=\(source) event_id=\(eventID)")
            return
        }
        lastAgentEventID = eventID
        scheduleAutomaticSleep(source: source)
    }

    private func scheduleAutomaticSleep(source: String) {
        guard !isPreparingAutomaticSleep else {
            log("ai_task_finished ignored=sleep_in_progress source=\(source)")
            return
        }

        autoSleepCountdownTimer?.invalidate()
        autoSleepDeadline = Date().addingTimeInterval(automaticSleepDelay)
        updateAutomaticSleepCountdown()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateAutomaticSleepCountdown()
        }
        timer.tolerance = 0.1
        autoSleepCountdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        log("ai_task_finished source=\(source) automatic_sleep_in_seconds=\(Int(automaticSleepDelay))")
    }

    private func updateAutomaticSleepCountdown() {
        guard let deadline = autoSleepDeadline else {
            statusMenuController?.setPendingAutoSleep(seconds: nil)
            return
        }

        let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        statusMenuController?.setPendingAutoSleep(seconds: remaining)
        if remaining == 0 {
            performAutomaticSleep()
        }
    }

    private func cancelPendingAutomaticSleep(reason: String) {
        let wasPending = autoSleepDeadline != nil
        clearPendingAutomaticSleep()
        if wasPending {
            log("automatic_sleep_cancelled reason=\(reason)")
        }
    }

    private func clearPendingAutomaticSleep() {
        autoSleepCountdownTimer?.invalidate()
        autoSleepCountdownTimer = nil
        autoSleepDeadline = nil
        statusMenuController?.setPendingAutoSleep(seconds: nil)
    }

    private func performAutomaticSleep() {
        clearPendingAutomaticSleep()
        guard Preferences.autoSleepAfterAgentTask, !isPreparingAutomaticSleep else { return }

        isPreparingAutomaticSleep = true
        sleepVerificationTimer?.invalidate()
        sleepVerificationTimer = nil

        let restoreResult = runHelper("off")
        let confirmedNormalSleep = SleepStateReader.isDisabled() == false
        log(
            "automatic_sleep restore_off_status=\(restoreResult.status) "
                + "confirmed_normal_sleep=\(confirmedNormalSleep) "
                + "stdout=\(restoreResult.stdout) stderr=\(restoreResult.stderr)"
        )
        guard restoreResult.status == 0, confirmedNormalSleep else {
            if Preferences.enabled {
                let compensation = runHelper("on")
                let compensated = compensation.status == 0 && SleepStateReader.isDisabled() == true
                log(
                    "automatic_sleep compensation_on_status=\(compensation.status) "
                        + "confirmed=\(compensated) "
                        + "stdout=\(compensation.stdout) stderr=\(compensation.stderr)"
                )
                if compensated {
                    lastAppliedState = true
                    failedSleepState = nil
                    nextSleepStateRetryAt = .distantPast
                    sleepRetryTimer?.invalidate()
                    sleepRetryTimer = nil
                    ensureStatusItem()
                } else {
                    markSleepStateFailure(true, now: Date())
                }
            } else {
                markSleepStateFailure(false, now: Date())
            }
            isPreparingAutomaticSleep = false
            updateSleepVerificationTimer()
            return
        }

        lastAppliedState = false
        failedSleepState = nil
        let sleepResult = runHelper(systemSleepHelperMode)
        log(
            "automatic_sleep sleep_now_status=\(sleepResult.status) "
                + "stdout=\(sleepResult.stdout) stderr=\(sleepResult.stderr)"
        )
        guard sleepResult.status == 0 else {
            finishAutomaticSleepCycle(reason: "sleep_now_failed")
            return
        }

        automaticSleepRecoveryTimer?.invalidate()
        let timer = Timer(timeInterval: automaticSleepRecoveryInterval, repeats: false) { [weak self] _ in
            guard let self, self.isPreparingAutomaticSleep else { return }
            self.finishAutomaticSleepCycle(reason: "sleep_recovery_timeout")
        }
        automaticSleepRecoveryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finishAutomaticSleepCycle(reason: String) {
        automaticSleepRecoveryTimer?.invalidate()
        automaticSleepRecoveryTimer = nil
        isPreparingAutomaticSleep = false
        apply(reason: reason, forceVerification: true)
        updateSleepVerificationTimer()
        updateClamshellPolling()
        statusMenuController?.refreshControls()
        log("automatic_sleep_cycle_finished reason=\(reason)")
    }

    private func applyCurrentControlState(reason: String) {
        apply(reason: reason)
    }

    private func apply(reason: String, forceVerification: Bool = false) {
        guard !isPreparingAutomaticSleep else { return }
        let shouldDisableSleep = SleepControlPolicy.shouldDisableSleep(enabled: Preferences.enabled)
        let now = Date()
        if failedSleepState == shouldDisableSleep, now < nextSleepStateRetryAt {
            return
        }

        if lastAppliedState == shouldDisableSleep {
            if failedSleepState == nil, !forceVerification {
                evaluateDisplaySleepForClosedLid(isKeepRunning: shouldDisableSleep, reason: reason)
                return
            }

            guard let actualState = SleepStateReader.isDisabled() else {
                if !hasLoggedMissingSleepState {
                    log("\(reason) sleep_state_unavailable")
                    hasLoggedMissingSleepState = true
                }
                markSleepStateFailure(shouldDisableSleep, now: now)
                return
            }

            hasLoggedMissingSleepState = false
            if actualState == shouldDisableSleep {
                failedSleepState = nil
                nextSleepStateRetryAt = .distantPast
                sleepRetryTimer?.invalidate()
                sleepRetryTimer = nil
                ensureStatusItem()
                evaluateDisplaySleepForClosedLid(isKeepRunning: shouldDisableSleep, reason: reason)
                return
            }

            log("\(reason) sleep_state_drift expected=\(shouldDisableSleep ? "on" : "off") actual=\(actualState ? "on" : "off")")
        }

        let mode = shouldDisableSleep ? "on" : "off"
        let result = runHelper(mode)
        log("\(reason) keep_running=\(mode) helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")

        guard result.status == 0 else {
            markSleepStateFailure(shouldDisableSleep, now: now)
            return
        }

        lastAppliedState = shouldDisableSleep
        let confirmedState = SleepStateReader.isDisabled()
        guard confirmedState == Optional(shouldDisableSleep) else {
            hasLoggedMissingSleepState = confirmedState == nil
            log("\(reason) sleep_state_confirmation_failed expected=\(mode) actual=\(confirmedState.map { $0 ? "on" : "off" } ?? "unknown")")
            markSleepStateFailure(shouldDisableSleep, now: now)
            return
        }

        hasLoggedMissingSleepState = false
        failedSleepState = nil
        nextSleepStateRetryAt = .distantPast
        sleepRetryTimer?.invalidate()
        sleepRetryTimer = nil
        ensureStatusItem()
        evaluateDisplaySleepForClosedLid(isKeepRunning: shouldDisableSleep, reason: reason)
    }

    private func markSleepStateFailure(_ expectedState: Bool, now: Date) {
        failedSleepState = expectedState
        nextSleepStateRetryAt = now.addingTimeInterval(helperRetryInterval)
        updateStatusError()

        sleepRetryTimer?.invalidate()
        let timer = Timer(timeInterval: helperRetryInterval, repeats: false) { [weak self] _ in
            self?.apply(reason: "retry", forceVerification: true)
        }
        sleepRetryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func evaluateDisplaySleepForClosedLid(isKeepRunning: Bool, reason: String) {
        guard Preferences.displaySleepOnLidClose else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            observedClamshellClosed = false
            updateClamshellPolling()
            return
        }

        guard isKeepRunning else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            observedClamshellClosed = false
            updateClamshellPolling()
            return
        }

        let clamshellClosed: Bool
        if observedClamshellClosed {
            clamshellClosed = true
        } else {
            guard let currentState = ClamshellStateReader.isClosed() else {
                didRequestDisplaySleepForClosedLid = false
                if !hasLoggedMissingClamshellState {
                    log("\(reason) clamshell_state_unavailable")
                    hasLoggedMissingClamshellState = true
                }
                return
            }
            clamshellClosed = currentState
        }
        hasLoggedMissingClamshellState = false

        guard clamshellClosed else {
            observedClamshellClosed = false
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            updateClamshellPolling()
            return
        }

        observedClamshellClosed = true
        updateClamshellPolling()

        let now = Date()
        guard now >= nextDisplaySleepRetryAt else { return }

        let result = runHelper(displaySleepHelperMode)
        if !didRequestDisplaySleepForClosedLid || result.status != 0 {
            log("\(reason) clamshell=closed display_sleep_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
        }
        if result.status == 0 {
            didRequestDisplaySleepForClosedLid = true
            nextDisplaySleepRetryAt = .distantFuture
            displaySleepRetryTimer?.invalidate()
            displaySleepRetryTimer = nil
        } else {
            nextDisplaySleepRetryAt = now.addingTimeInterval(helperRetryInterval)
            scheduleDisplaySleepRetry(isKeepRunning: isKeepRunning)
        }
    }

    private func scheduleDisplaySleepRetry(isKeepRunning: Bool) {
        displaySleepRetryTimer?.invalidate()
        let timer = Timer(timeInterval: helperRetryInterval, repeats: false) { [weak self] _ in
            self?.evaluateDisplaySleepForClosedLid(
                isKeepRunning: isKeepRunning,
                reason: "display_sleep_retry"
            )
        }
        displaySleepRetryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateStatus(isKeepRunning: Bool) {
        guard let button = statusItem?.button else { return }
        statusMenuController?.setSystemError(false)
        let strings = AppStrings.current()
        if !Preferences.enabled {
            button.image = offImage
            button.toolTip = strings.tooltipDisabled
        } else {
            button.image = isKeepRunning ? onImage : offImage
            button.toolTip = isKeepRunning ? strings.tooltipOn : strings.tooltipOff
        }
    }

    private func refreshStatus(isKeepRunning: Bool) {
        if failedSleepState == nil {
            updateStatus(isKeepRunning: isKeepRunning)
        } else {
            updateStatusError()
        }
    }

    private func updateStatusError() {
        if statusItem == nil {
            ensureStatusItem()
        }
        guard let button = statusItem?.button else { return }
        button.image = errorImage
        button.toolTip = AppStrings.current().tooltipError
        statusMenuController?.setSystemError(true)
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

        LogFileRotation.rotateIfNeeded(logURL: url, incomingDataSize: data.count)

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

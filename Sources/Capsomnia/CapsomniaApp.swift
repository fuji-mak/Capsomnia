import AppKit
import Foundation

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var failedSleepState: Bool?
    private var nextSleepStateRetryAt = Date.distantPast
    private var nextSleepStateVerificationAt = Date.distantPast
    private var nextDisplaySleepRetryAt = Date.distantPast
    private var didRequestDisplaySleepForClosedLid = false
    private var hasLoggedMissingClamshellState = false
    private var hasLoggedMissingSleepState = false
    private var shouldRestoreSleepOnTerminate = true
    private var pollingTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    private var statusMenuController: StatusMenuController?
    private let onImage = DotImage.makeRing(color: NSColor(calibratedWhite: 0.60, alpha: 1.0))
    private let offImage = DotImage.makeFilled(color: NSColor(calibratedWhite: 0.60, alpha: 1.0))
    private let errorImage = DotImage.makeFilled(color: .systemRed)
    private let helperRetryInterval: TimeInterval = 5
    private let sleepStateVerificationInterval: TimeInterval = 10
    private let displaySleepRefreshInterval: TimeInterval = 2

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfNewerInteractiveDuplicate() {
            return
        }

        Preferences.registerDefaults()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOpenMenuNotification),
            name: openMenuNotificationName,
            object: appLabel
        )

        NSApp.setActivationPolicy(.accessory)
        ensureStatusItem()
        installSignalHandlers()
        installPollingMonitor()
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
            name: openMenuNotificationName,
            object: appLabel,
            userInfo: nil
        )
        existing.activate(options: [])
        log("duplicate_instance existing_pid=\(existing.processIdentifier) terminate_without_restore")
        NSApp.terminate(nil)
        return true
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
            onDisplaySleepChange: { [weak self] enabled in
                self?.setDisplaySleepOnLidClose(enabled)
            },
            onLaunchAtLoginChange: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            onLanguageChange: { [weak self] language in
                self?.setLanguage(language)
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
        }
        applyCurrentControlState(reason: "preference_enabled")
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

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAgentManager.setEnabled(enabled)
            Preferences.launchAtLogin = enabled
            log("preference launch_at_login=\(enabled ? "on" : "off")")
        } catch {
            log("preference launch_at_login_error=\(error.localizedDescription)")
        }
        statusMenuController?.refreshControls()
    }

    private func setDisplaySleepOnLidClose(_ enabled: Bool) {
        Preferences.displaySleepOnLidClose = enabled
        if enabled {
            let isKeepRunning = lastAppliedState ?? Preferences.enabled
            evaluateDisplaySleepForClosedLid(isKeepRunning: isKeepRunning, reason: "preference")
        } else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
        }
        statusMenuController?.refreshControls()
        log("preference display_sleep_on_lid_close=\(enabled ? "on" : "off")")
    }

    private func installPollingMonitor() {
        pollingTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.applyCurrentControlState(reason: "poll")
        }
        timer.tolerance = 0.05
        pollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        log("polling_ready interval_ms=250 tolerance_ms=50")
    }

    private func applyCurrentControlState(reason: String) {
        apply(reason: reason)
    }

    private func apply(reason: String) {
        let shouldDisableSleep = SleepControlPolicy.shouldDisableSleep(enabled: Preferences.enabled)
        let now = Date()
        if failedSleepState == shouldDisableSleep, now < nextSleepStateRetryAt {
            return
        }

        if lastAppliedState == shouldDisableSleep {
            if failedSleepState == nil, now < nextSleepStateVerificationAt {
                evaluateDisplaySleepForClosedLid(isKeepRunning: shouldDisableSleep, reason: reason)
                return
            }

            guard let actualState = SleepStateReader.isDisabled() else {
                if !hasLoggedMissingSleepState {
                    log("\(reason) sleep_state_unavailable")
                    hasLoggedMissingSleepState = true
                }
                failedSleepState = shouldDisableSleep
                nextSleepStateRetryAt = now.addingTimeInterval(helperRetryInterval)
                nextSleepStateVerificationAt = nextSleepStateRetryAt
                updateStatusError()
                return
            }

            hasLoggedMissingSleepState = false
            if actualState == shouldDisableSleep {
                failedSleepState = nil
                nextSleepStateRetryAt = .distantPast
                nextSleepStateVerificationAt = now.addingTimeInterval(sleepStateVerificationInterval)
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
            failedSleepState = shouldDisableSleep
            nextSleepStateRetryAt = now.addingTimeInterval(helperRetryInterval)
            updateStatusError()
            return
        }

        lastAppliedState = shouldDisableSleep
        let confirmedState = SleepStateReader.isDisabled()
        guard confirmedState == Optional(shouldDisableSleep) else {
            hasLoggedMissingSleepState = confirmedState == nil
            failedSleepState = shouldDisableSleep
            nextSleepStateRetryAt = now.addingTimeInterval(helperRetryInterval)
            nextSleepStateVerificationAt = nextSleepStateRetryAt
            log("\(reason) sleep_state_confirmation_failed expected=\(mode) actual=\(confirmedState.map { $0 ? "on" : "off" } ?? "unknown")")
            updateStatusError()
            return
        }

        hasLoggedMissingSleepState = false
        failedSleepState = nil
        nextSleepStateRetryAt = .distantPast
        nextSleepStateVerificationAt = now.addingTimeInterval(sleepStateVerificationInterval)
        ensureStatusItem()
        evaluateDisplaySleepForClosedLid(isKeepRunning: shouldDisableSleep, reason: reason)
    }

    private func evaluateDisplaySleepForClosedLid(isKeepRunning: Bool, reason: String) {
        guard Preferences.displaySleepOnLidClose else {
            didRequestDisplaySleepForClosedLid = false
            nextDisplaySleepRetryAt = .distantPast
            return
        }

        guard isKeepRunning else {
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

        let now = Date()
        guard now >= nextDisplaySleepRetryAt else { return }

        let result = runHelper(displaySleepHelperMode)
        if !didRequestDisplaySleepForClosedLid || result.status != 0 {
            log("\(reason) clamshell=closed display_sleep_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
        }
        if result.status == 0 {
            didRequestDisplaySleepForClosedLid = true
            nextDisplaySleepRetryAt = now.addingTimeInterval(displaySleepRefreshInterval)
        } else {
            nextDisplaySleepRetryAt = now.addingTimeInterval(helperRetryInterval)
        }
    }

    private func updateStatus(isKeepRunning: Bool) {
        guard let button = statusItem?.button else { return }
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

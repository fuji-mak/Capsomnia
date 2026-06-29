import AppKit
import CoreGraphics
import Foundation

private let appName = "Capsomnia"
private let appLabel = "com.github.fuji-mak.capsomnia"
private let helperPath = "/Library/PrivilegedHelperTools/capsomnia-pmset"
private let logDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/Capsomnia")
private let logPath = logDirectoryURL
    .appendingPathComponent("capsomnia.log")
    .path

private enum PreferenceKey {
    static let showMenuBarIcon = "ShowMenuBarIcon"
    static let launchAtLogin = "LaunchAtLogin"
    static let didCompleteInitialSetup = "DidCompleteInitialSetup"
}

private enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.showMenuBarIcon: true,
            PreferenceKey.launchAtLogin: true,
            PreferenceKey.didCompleteInitialSetup: false
        ])
    }

    static var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: PreferenceKey.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: PreferenceKey.showMenuBarIcon) }
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: PreferenceKey.launchAtLogin) }
        set { defaults.set(newValue, forKey: PreferenceKey.launchAtLogin) }
    }

    static var didCompleteInitialSetup: Bool {
        get { defaults.bool(forKey: PreferenceKey.didCompleteInitialSetup) }
        set { defaults.set(newValue, forKey: PreferenceKey.didCompleteInitialSetup) }
    }
}

private struct LaunchAgentError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private enum LaunchAgentManager {
    private static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(appLabel).plist")
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try writeLaunchAgent()
            try runLaunchctl(["enable", "gui/\(getuid())/\(appLabel)"])
        } else {
            try runLaunchctl(["disable", "gui/\(getuid())/\(appLabel)"])
        }
    }

    private static func writeLaunchAgent() throws {
        try FileManager.default.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: logDirectoryURL,
            withIntermediateDirectories: true
        )

        let executablePath = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        let propertyList: [String: Any] = [
            "Label": appLabel,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "StandardOutPath": logDirectoryURL.appendingPathComponent("stdout.log").path,
            "StandardErrorPath": logDirectoryURL.appendingPathComponent("stderr.log").path
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private static func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = read(stderrPipe.fileHandleForReading)
            let stdout = read(stdoutPipe.fileHandleForReading)
            throw LaunchAgentError(
                message: "launchctl \(arguments.joined(separator: " ")) failed: \(stderr.isEmpty ? stdout : stderr)"
            )
        }
    }

    private static func read(_ handle: FileHandle) -> String {
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var eventTap: CFMachPort?
    private var pollingTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    private var stateMenuItem: NSMenuItem?
    private var settingsWindowController: SettingsWindowController?
    private let onImage = DotImage.make(color: .systemGreen)
    private let offImage = DotImage.make(color: NSColor(calibratedWhite: 0.58, alpha: 1.0))

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        NSApp.setActivationPolicy(.accessory)
        syncStatusItemVisibility()
        installSignalHandlers()
        installEventTapOrFallback()
        log("start")
        applyCurrentCapsLockState(reason: "startup")

        if !Preferences.didCompleteInitialSetup {
            showSettingsWindow(initialSetup: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow(initialSetup: !Preferences.didCompleteInitialSetup)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        log("terminate restore_off")
        _ = runHelper("off")
    }

    private func syncStatusItemVisibility() {
        if Preferences.showMenuBarIcon {
            if statusItem == nil {
                installStatusItem()
            }

            let capsLockOn = lastAppliedState
                ?? CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
            updateStatus(capsLockOn: capsLockOn, helperStatus: nil)
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            stateMenuItem = nil
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

        let menu = NSMenu()
        let stateItem = NSMenuItem(title: "Caps Lock: checking", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        stateMenuItem = stateItem
        menu.addItem(stateItem)
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        updateStatus(capsLockOn: false, helperStatus: nil)
    }

    @objc private func openSettings() {
        showSettingsWindow(initialSetup: !Preferences.didCompleteInitialSetup)
    }

    @objc private func quit() {
        log("menu_quit")
        NSApp.terminate(nil)
    }

    private func showSettingsWindow(initialSetup: Bool) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                onShowMenuBarIconChange: { [weak self] enabled in
                    self?.setShowMenuBarIcon(enabled)
                },
                onLaunchAtLoginChange: { [weak self] enabled in
                    self?.setLaunchAtLogin(enabled)
                },
                onFinishInitialSetup: {
                    Preferences.didCompleteInitialSetup = true
                }
            )
        }

        settingsWindowController?.show(initialSetup: initialSetup)
    }

    private func setShowMenuBarIcon(_ enabled: Bool) {
        Preferences.showMenuBarIcon = enabled
        syncStatusItemVisibility()
        log("preference show_menu_bar_icon=\(enabled ? "on" : "off")")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        Preferences.launchAtLogin = enabled

        do {
            try LaunchAgentManager.setEnabled(enabled)
            settingsWindowController?.setLaunchAtLoginError(nil)
            log("preference launch_at_login=\(enabled ? "on" : "off")")
        } catch {
            settingsWindowController?.setLaunchAtLoginError(error.localizedDescription)
            log("preference launch_at_login_error=\(error.localizedDescription)")
        }
    }

    private func installEventTapOrFallback() {
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
            installPollingMonitor()
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("event_tap_ready")
        installPollingMonitor()
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
        guard lastAppliedState != capsLockOn else { return }
        lastAppliedState = capsLockOn

        let mode = capsLockOn ? "on" : "off"
        let result = runHelper(mode)
        updateStatus(capsLockOn: capsLockOn, helperStatus: result.status)
        log("\(reason) capslock=\(mode) helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
    }

    private func updateStatus(capsLockOn: Bool, helperStatus: Int32?) {
        let title = capsLockOn ? "Caps Lock: ON / sleep disabled" : "Caps Lock: OFF / normal sleep"
        stateMenuItem?.title = helperStatus.map { "\(title) / pmset=\($0)" } ?? title

        guard let button = statusItem?.button else { return }
        button.image = capsLockOn ? onImage : offImage
        button.toolTip = capsLockOn
            ? "Caps Lock ON: processes stay awake"
            : "Caps Lock OFF: normal sleep"
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
                self?.log("signal=\(signalNumber) restore_off")
                _ = self?.runHelper("off")
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

private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let showMenuBarIconButton: NSButton
    private let launchAtLoginButton: NSButton
    private let launchAtLoginErrorLabel: NSTextField
    private let onShowMenuBarIconChange: (Bool) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onFinishInitialSetup: () -> Void
    private var isInitialSetup = false

    init(
        onShowMenuBarIconChange: @escaping (Bool) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onFinishInitialSetup: @escaping () -> Void
    ) {
        self.showMenuBarIconButton = NSButton(checkboxWithTitle: "Show menu bar icon", target: nil, action: nil)
        self.launchAtLoginButton = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
        self.launchAtLoginErrorLabel = NSTextField(labelWithString: "")
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onFinishInitialSetup = onFinishInitialSetup

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Capsomnia Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        buildContent()
        updateValues()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(initialSetup: Bool) {
        isInitialSetup = initialSetup
        updateValues()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setLaunchAtLoginError(_ message: String?) {
        launchAtLoginErrorLabel.stringValue = message ?? ""
        launchAtLoginErrorLabel.isHidden = message == nil
    }

    func windowWillClose(_ notification: Notification) {
        finishInitialSetupIfNeeded()
    }

    private func buildContent() {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Initial Settings")
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)

        let noteLabel = NSTextField(labelWithString: "Open Capsomnia again to change these later.")
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.font = .systemFont(ofSize: 12)

        showMenuBarIconButton.target = self
        showMenuBarIconButton.action = #selector(showMenuBarIconChanged)

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)

        launchAtLoginErrorLabel.textColor = .systemRed
        launchAtLoginErrorLabel.font = .systemFont(ofSize: 11)
        launchAtLoginErrorLabel.lineBreakMode = .byTruncatingTail
        launchAtLoginErrorLabel.isHidden = true

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [NSView(), doneButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fill

        let stack = NSStackView(views: [
            titleLabel,
            noteLabel,
            showMenuBarIconButton,
            launchAtLoginButton,
            launchAtLoginErrorLabel,
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        window?.contentView = contentView

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchAtLoginErrorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func updateValues() {
        showMenuBarIconButton.state = Preferences.showMenuBarIcon ? .on : .off
        launchAtLoginButton.state = Preferences.launchAtLogin ? .on : .off
    }

    private func finishInitialSetupIfNeeded() {
        guard isInitialSetup else { return }
        isInitialSetup = false
        onShowMenuBarIconChange(showMenuBarIconButton.state == .on)
        onLaunchAtLoginChange(launchAtLoginButton.state == .on)
        onFinishInitialSetup()
    }

    @objc private func showMenuBarIconChanged(_ sender: NSButton) {
        onShowMenuBarIconChange(sender.state == .on)
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        onLaunchAtLoginChange(sender.state == .on)
    }

    @objc private func done() {
        finishInitialSetupIfNeeded()
        close()
    }
}

private enum DotImage {
    static func make(color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
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

let app = NSApplication.shared
let delegate = Capsomnia()
app.delegate = delegate
app.run()

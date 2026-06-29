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
private let brandLEDColor = NSColor(
    srgbRed: 184.0 / 255.0,
    green: 255.0 / 255.0,
    blue: 31.0 / 255.0,
    alpha: 1.0
)

/// Colors lifted straight from the landing page (docs/styles.css :root).
private enum Brand {
    static func srgb(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    static let bg = srgb(0x000000)
    static let surface = srgb(0x0A0A0A)
    static let surface2 = srgb(0x111111)
    static let border = srgb(0x1F1F1F)
    static let borderStrong = srgb(0x2A2A2A)
    static let text = srgb(0xF2F4EC)
    static let textDim = srgb(0xA7AD9C)
    static let textFaint = srgb(0x6F7466)
    static let led = brandLEDColor
    static let ledBright = srgb(0xD8FF63)
    static let ledDeep = srgb(0x92F21D)
    static let offDot = srgb(0x2C2C2C)
    static let offDotBorder = srgb(0x3A3A3A)
}

private enum AppLanguage: String, CaseIterable {
    case english = "en"
    case japanese = "ja"

    static var defaultLanguage: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("ja") == true ? .japanese : .english
    }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .japanese:
            "日本語"
        }
    }
}

private struct AppStrings {
    let showMenuBarIcon: String
    let showMenuBarIconDesc: String
    let language: String
    let openAtLogin: String
    let openAtLoginDesc: String
    let openCapsomnia: String
    let quit: String
    let settingsTitle: String
    let initialSettingsTitle: String
    let initialSettingsNote: String
    let welcomeTitle: String
    let explainerOnTitle: String
    let explainerOnDesc: String
    let explainerOffTitle: String
    let explainerOffDesc: String
    let preferencesHeading: String
    let done: String
    let getStarted: String
    let tooltipOn: String
    let tooltipOff: String

    static func current() -> AppStrings {
        switch Preferences.language {
        case .english:
            AppStrings(
                showMenuBarIcon: "Show menu bar icon",
                showMenuBarIconDesc: "Display the LED status dot in the menu bar.",
                language: "Language",
                openAtLogin: "Open at login",
                openAtLoginDesc: "Launch Capsomnia automatically after you sign in.",
                openCapsomnia: "Open Capsomnia",
                quit: "Quit",
                settingsTitle: "Settings",
                initialSettingsTitle: "Welcome to Capsomnia",
                initialSettingsNote: "Open Capsomnia again any time to change these.",
                welcomeTitle: "Welcome to Capsomnia",
                explainerOnTitle: "Caps Lock on",
                explainerOnDesc: "System sleep is disabled — work keeps running, lid open or closed.",
                explainerOffTitle: "Caps Lock off",
                explainerOffDesc: "Normal sleep behavior resumes.",
                preferencesHeading: "Preferences",
                done: "Done",
                getStarted: "Get started",
                tooltipOn: "Caps Lock ON: processes stay awake",
                tooltipOff: "Caps Lock OFF: normal sleep"
            )
        case .japanese:
            AppStrings(
                showMenuBarIcon: "メニューバーに表示",
                showMenuBarIconDesc: "メニューバーにLEDステータスを表示します。",
                language: "言語",
                openAtLogin: "ログイン時に起動",
                openAtLoginDesc: "サインイン後にCapsomniaを自動で起動します。",
                openCapsomnia: "Capsomniaを開く",
                quit: "終了",
                settingsTitle: "設定",
                initialSettingsTitle: "Capsomniaへようこそ",
                initialSettingsNote: "あとからCapsomniaを開けばいつでも変更できます。",
                welcomeTitle: "Capsomniaへようこそ",
                explainerOnTitle: "Caps Lock ON",
                explainerOnDesc: "システムスリープを無効化。蓋を閉じても作業が走り続けます。",
                explainerOffTitle: "Caps Lock OFF",
                explainerOffDesc: "通常のスリープ動作に戻ります。",
                preferencesHeading: "環境設定",
                done: "完了",
                getStarted: "はじめる",
                tooltipOn: "Caps Lock ON: スリープ抑止中",
                tooltipOff: "Caps Lock OFF: 通常のスリープ動作"
            )
        }
    }
}

private enum PreferenceKey {
    static let showMenuBarIcon = "ShowMenuBarIcon"
    static let language = "Language"
    static let launchAtLogin = "LaunchAtLogin"
    static let didCompleteInitialSetup = "DidCompleteInitialSetup"
}

private enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.showMenuBarIcon: true,
            PreferenceKey.language: AppLanguage.defaultLanguage.rawValue,
            PreferenceKey.launchAtLogin: true,
            PreferenceKey.didCompleteInitialSetup: false
        ])
    }

    static var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: PreferenceKey.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: PreferenceKey.showMenuBarIcon) }
    }

    static var language: AppLanguage {
        get {
            AppLanguage(rawValue: defaults.string(forKey: PreferenceKey.language) ?? "")
                ?? AppLanguage.defaultLanguage
        }
        set { defaults.set(newValue.rawValue, forKey: PreferenceKey.language) }
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
    static func setEnabled(_ enabled: Bool) throws {
        try runLaunchctl([
            enabled ? "enable" : "disable",
            "gui/\(getuid())/\(appLabel)"
        ])
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
    private var settingsWindowController: SettingsWindowController?
    private let onImage = DotImage.make(color: brandLEDColor)
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
                onLanguageChange: { [weak self] language in
                    self?.setLanguage(language)
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
        updateStatus(capsLockOn: capsLockOn)
        log("\(reason) capslock=\(mode) helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
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
    private static let contentWidth: CGFloat = 400

    private let headerIcon = NSImageView()
    private let titleLabel = brandLabel(size: 21, weight: .bold, color: Brand.text)

    private let explainerCard = brandCard()
    private let explainerOnTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOnDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let explainerOffTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOffDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)

    private let preferencesHeading = brandLabel(size: 11, weight: .semibold, color: Brand.textFaint)

    private let menuBarTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let menuBarDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let menuBarToggle = LEDToggle(isOn: Preferences.showMenuBarIcon)

    private let openAtLoginTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let openAtLoginDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let openAtLoginToggle = LEDToggle(isOn: Preferences.launchAtLogin)
    private var openAtLoginRow = NSView()
    private var openAtLoginDivider = brandDivider()

    private let languageTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let languageSegment = SegmentedPill(
        items: AppLanguage.allCases.map { (title: $0.displayName, value: $0.rawValue) },
        selected: Preferences.language.rawValue
    )

    private let noteLabel = brandLabel(size: 12, color: Brand.textFaint, wraps: true)
    private let doneButton = LEDButton()

    private let onShowMenuBarIconChange: (Bool) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onFinishInitialSetup: () -> Void
    private var isInitialSetup = false

    init(
        onShowMenuBarIconChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping (AppLanguage) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onFinishInitialSetup: @escaping () -> Void
    ) {
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLanguageChange = onLanguageChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onFinishInitialSetup = onFinishInitialSetup

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.contentWidth, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = Brand.bg
        window.appearance = NSAppearance(named: .darkAqua)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.center()

        super.init(window: window)

        window.delegate = self
        buildContent()
        updateValues()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func reloadText() {
        let strings = AppStrings.current()

        window?.title = isInitialSetup ? strings.welcomeTitle : strings.settingsTitle
        titleLabel.stringValue = isInitialSetup ? strings.welcomeTitle : "Capsomnia"

        explainerOnTitle.stringValue = strings.explainerOnTitle
        explainerOnDesc.stringValue = strings.explainerOnDesc
        explainerOffTitle.stringValue = strings.explainerOffTitle
        explainerOffDesc.stringValue = strings.explainerOffDesc

        preferencesHeading.stringValue = strings.preferencesHeading.uppercased()

        menuBarTitle.stringValue = strings.showMenuBarIcon
        menuBarDesc.stringValue = strings.showMenuBarIconDesc
        openAtLoginTitle.stringValue = strings.openAtLogin
        openAtLoginDesc.stringValue = strings.openAtLoginDesc
        languageTitle.stringValue = strings.language

        noteLabel.stringValue = strings.initialSettingsNote
        doneButton.title = isInitialSetup ? strings.getStarted : strings.done

        explainerCard.isHidden = !isInitialSetup
        openAtLoginRow.isHidden = isInitialSetup
        openAtLoginDivider.isHidden = isInitialSetup
        noteLabel.isHidden = !isInitialSetup

        updateValues()
    }

    func show(initialSetup: Bool) {
        isInitialSetup = initialSetup
        reloadText()
        resizeToFit()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        finishInitialSetupIfNeeded()
    }

    private func resizeToFit() {
        guard let contentView = window?.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let height = contentView.fittingSize.height
        window?.setContentSize(NSSize(width: Self.contentWidth, height: height))
    }

    private func buildContent() {
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Brand.bg.cgColor

        headerIcon.image = BrandIcon.make(diameter: 60)
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.alignment = .center

        let header = NSStackView(views: [headerIcon, titleLabel])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 10
        header.setCustomSpacing(14, after: headerIcon)

        buildExplainerCard()

        let preferencesCard = buildPreferencesCard()

        doneButton.onClick = { [weak self] in self?.done() }

        let stack = NSStackView(views: [
            header,
            explainerCard,
            preferencesHeading,
            preferencesCard,
            noteLabel,
            doneButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.setCustomSpacing(20, after: header)
        stack.setCustomSpacing(8, after: preferencesHeading)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        window?.contentView = contentView

        // Full-width children inside the leading-aligned stack.
        for child in [header, explainerCard, preferencesCard, noteLabel, doneButton] {
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        reloadText()
    }

    private func buildExplainerCard() {
        let onRow = explainerRow(dot: brandStatusDot(on: true), title: explainerOnTitle, desc: explainerOnDesc)
        let offRow = explainerRow(dot: brandStatusDot(on: false), title: explainerOffTitle, desc: explainerOffDesc)

        let inner = NSStackView(views: [onRow, offRow])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 14
        inner.translatesAutoresizingMaskIntoConstraints = false

        explainerCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: explainerCard.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: explainerCard.trailingAnchor, constant: -16),
            inner.topAnchor.constraint(equalTo: explainerCard.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: explainerCard.bottomAnchor, constant: -16),
            onRow.widthAnchor.constraint(equalTo: inner.widthAnchor),
            offRow.widthAnchor.constraint(equalTo: inner.widthAnchor)
        ])
    }

    private func buildPreferencesCard() -> NSView {
        let card = brandCard()

        menuBarToggle.onToggle = { [weak self] enabled in self?.onShowMenuBarIconChange(enabled) }
        openAtLoginToggle.onToggle = { [weak self] enabled in
            self?.onLaunchAtLoginChange(enabled)
            self?.updateValues()
        }
        languageSegment.onSelect = { [weak self] rawValue in
            guard let language = AppLanguage(rawValue: rawValue) else { return }
            self?.onLanguageChange(language)
        }

        let menuBarRow = settingRow(title: menuBarTitle, desc: menuBarDesc, accessory: menuBarToggle)
        openAtLoginRow = settingRow(title: openAtLoginTitle, desc: openAtLoginDesc, accessory: openAtLoginToggle)
        let languageRow = settingRow(title: languageTitle, desc: nil, accessory: languageSegment)

        let divider1 = openAtLoginDivider
        let divider2 = brandDivider()

        let inner = NSStackView(views: [menuBarRow, divider1, openAtLoginRow, divider2, languageRow])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 14
        inner.setCustomSpacing(14, after: menuBarRow)
        inner.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        for row in [menuBarRow, divider1, openAtLoginRow, divider2, languageRow] {
            row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }
        return card
    }

    /// A "title + optional description / accessory on the right" row.
    private func settingRow(title: NSTextField, desc: NSTextField?, accessory: NSView) -> NSView {
        let texts: NSView
        if let desc {
            let column = NSStackView(views: [title, desc])
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 2
            texts = column
        } else {
            texts = title
        }
        texts.translatesAutoresizingMaskIntoConstraints = false
        texts.setContentHuggingPriority(.defaultLow, for: .horizontal)

        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = NSStackView(views: [texts, accessory])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func explainerRow(dot: NSView, title: NSTextField, desc: NSTextField) -> NSView {
        let column = NSStackView(views: [title, desc])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 2
        column.translatesAutoresizingMaskIntoConstraints = false

        let dotHolder = NSView()
        dotHolder.translatesAutoresizingMaskIntoConstraints = false
        dotHolder.addSubview(dot)
        NSLayoutConstraint.activate([
            dotHolder.widthAnchor.constraint(equalToConstant: 12),
            dot.topAnchor.constraint(equalTo: dotHolder.topAnchor, constant: 4),
            dot.leadingAnchor.constraint(equalTo: dotHolder.leadingAnchor),
            dot.bottomAnchor.constraint(lessThanOrEqualTo: dotHolder.bottomAnchor)
        ])

        let row = NSStackView(views: [dotHolder, column])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func updateValues() {
        menuBarToggle.setOn(Preferences.showMenuBarIcon)
        openAtLoginToggle.setOn(Preferences.launchAtLogin)
        languageSegment.setSelected(Preferences.language.rawValue)
    }

    private func finishInitialSetupIfNeeded() {
        guard isInitialSetup else { return }
        isInitialSetup = false
        onShowMenuBarIconChange(menuBarToggle.isOn)
        if let language = AppLanguage(rawValue: languageSegment.selectedValue) {
            onLanguageChange(language)
        }
        onFinishInitialSetup()
    }

    private func done() {
        finishInitialSetupIfNeeded()
        close()
    }
}

// MARK: - Branded controls

/// On/off pill toggle drawn in the landing-page LED palette.
private final class LEDToggle: NSView {
    private let track = CALayer()
    private let knob = CALayer()
    private(set) var isOn: Bool
    var onToggle: ((Bool) -> Void)?

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(x: 0, y: 0, width: 42, height: 24))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 42).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true

        track.frame = NSRect(x: 0, y: 0, width: 42, height: 24)
        track.cornerRadius = 12
        layer?.addSublayer(track)

        knob.frame = NSRect(x: 3, y: 3, width: 18, height: 18)
        knob.cornerRadius = 9
        knob.backgroundColor = NSColor.white.cgColor
        knob.shadowColor = NSColor.black.cgColor
        knob.shadowOpacity = 0.35
        knob.shadowRadius = 2
        knob.shadowOffset = CGSize(width: 0, height: -1)
        layer?.addSublayer(knob)

        apply(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    func setOn(_ value: Bool) {
        isOn = value
        apply(animated: false)
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        apply(animated: true)
        onToggle?(isOn)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func apply(animated: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.18)
        track.backgroundColor = (isOn ? Brand.led : Brand.offDot).cgColor
        knob.frame.origin.x = isOn ? 21 : 3
        CATransaction.commit()
    }
}

/// Segmented control matching the landing-page EN/JA language switch.
private final class SegmentedPill: NSView {
    private struct Segment {
        let value: String
        let container: ClickableView
        let label: NSTextField
    }

    private var segments: [Segment] = []
    private(set) var selectedValue: String
    var onSelect: ((String) -> Void)?

    init(items: [(title: String, value: String)], selected: String) {
        selectedValue = selected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = Brand.surface2.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Brand.borderStrong.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for item in items {
            let container = ClickableView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 8
            container.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: item.title)
            label.font = .systemFont(ofSize: 12, weight: .bold)
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: 24),
                container.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 10)
            ])

            let value = item.value
            container.onClick = { [weak self] in self?.select(value) }
            stack.addArrangedSubview(container)
            segments.append(Segment(value: value, container: container, label: label))
        }

        updateSelection()
    }

    required init?(coder: NSCoder) { nil }

    func setSelected(_ value: String) {
        selectedValue = value
        updateSelection()
    }

    private func select(_ value: String) {
        guard value != selectedValue else { return }
        selectedValue = value
        updateSelection()
        onSelect?(value)
    }

    private func updateSelection() {
        for segment in segments {
            let isSelected = segment.value == selectedValue
            segment.container.layer?.backgroundColor = isSelected ? Brand.led.cgColor : NSColor.clear.cgColor
            segment.label.textColor = isSelected ? .black : Brand.textDim
        }
    }
}

/// LED-green primary button matching the landing-page CTA.
private final class LEDButton: NSView {
    private let label = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?

    var title: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = Brand.led.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .black
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        ))
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = Brand.ledBright.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = Brand.led.cgColor
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// A plain view that forwards a click as a closure.
private final class ClickableView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Branded view factories

private func brandLabel(
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor,
    wraps: Bool = false
) -> NSTextField {
    let label = NSTextField(labelWithString: "")
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.translatesAutoresizingMaskIntoConstraints = false
    if wraps {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    return label
}

private func brandCard() -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = Brand.surface.cgColor
    view.layer?.cornerRadius = 14
    view.layer?.borderWidth = 1
    view.layer?.borderColor = Brand.border.cgColor
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

private func brandDivider() -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = Brand.border.cgColor
    view.translatesAutoresizingMaskIntoConstraints = false
    view.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return view
}

private func brandStatusDot(on: Bool) -> NSView {
    let dot = NSView()
    dot.wantsLayer = true
    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
    dot.heightAnchor.constraint(equalToConstant: 12).isActive = true
    dot.layer?.cornerRadius = 6
    if on {
        dot.layer?.backgroundColor = Brand.led.cgColor
        dot.layer?.shadowColor = Brand.led.cgColor
        dot.layer?.shadowOpacity = 0.85
        dot.layer?.shadowRadius = 5
        dot.layer?.shadowOffset = .zero
        dot.layer?.masksToBounds = false
    } else {
        dot.layer?.backgroundColor = Brand.offDot.cgColor
        dot.layer?.borderWidth = 1
        dot.layer?.borderColor = Brand.offDotBorder.cgColor
    }
    return dot
}

private enum BrandIcon {
    static func make(diameter: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: diameter, height: diameter))
        image.lockFocus()
        let center = NSPoint(x: diameter / 2, y: diameter / 2)
        if let glow = NSGradient(colors: [
            Brand.ledBright.withAlphaComponent(0.95),
            Brand.led.withAlphaComponent(0.45),
            Brand.led.withAlphaComponent(0.0)
        ]) {
            glow.draw(fromCenter: center, radius: 0, toCenter: center, radius: diameter / 2, options: [])
        }
        Brand.led.setFill()
        let radius = diameter * 0.20
        NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
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

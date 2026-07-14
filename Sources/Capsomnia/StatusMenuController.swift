import AppKit

final class StatusMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let onEnabledChange: (Bool) -> Void
    private let onAutoSleepAfterAgentTaskChange: (Bool) -> Void
    private let onDisplaySleepChange: (Bool) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onCancelPendingAutoSleep: () -> Void
    private let onMenuOpen: () -> Void
    private let onQuit: () -> Void

    private var enabledRow: StatusMenuToggleRow?
    private var autoSleepAfterAgentTaskItem: NSMenuItem?
    private var cancelPendingAutoSleepItem: NSMenuItem?
    private var displaySleepItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var errorItem: NSMenuItem?
    private var languageItems: [AppLanguage: NSMenuItem] = [:]
    private var hasSystemError = false
    private var pendingAutoSleepSeconds: Int?

    init(
        onEnabledChange: @escaping (Bool) -> Void,
        onAutoSleepAfterAgentTaskChange: @escaping (Bool) -> Void,
        onDisplaySleepChange: @escaping (Bool) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping (AppLanguage) -> Void,
        onCancelPendingAutoSleep: @escaping () -> Void,
        onMenuOpen: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onEnabledChange = onEnabledChange
        self.onAutoSleepAfterAgentTaskChange = onAutoSleepAfterAgentTaskChange
        self.onDisplaySleepChange = onDisplaySleepChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onLanguageChange = onLanguageChange
        self.onCancelPendingAutoSleep = onCancelPendingAutoSleep
        self.onMenuOpen = onMenuOpen
        self.onQuit = onQuit
        super.init()

        menu.autoenablesItems = false
        menu.minimumWidth = 300
        menu.delegate = self
        rebuild()
    }

    func menuWillOpen(_ menu: NSMenu) {
        onMenuOpen()
        refreshControls()
    }

    func reloadText() {
        rebuild()
    }

    func refreshControls() {
        enabledRow?.setOn(Preferences.enabled)
        autoSleepAfterAgentTaskItem?.state = Preferences.autoSleepAfterAgentTask ? .on : .off
        displaySleepItem?.state = Preferences.displaySleepOnLidClose ? .on : .off
        launchAtLoginItem?.state = Preferences.launchAtLogin ? .on : .off
        errorItem?.isHidden = !hasSystemError
        for (language, item) in languageItems {
            item.state = language == Preferences.language ? .on : .off
        }
        updatePendingAutoSleepItem()
    }

    func setPendingAutoSleep(seconds: Int?) {
        pendingAutoSleepSeconds = seconds
        updatePendingAutoSleepItem()
    }

    func setSystemError(_ hasError: Bool) {
        hasSystemError = hasError
        errorItem?.isHidden = !hasError
    }

    private func rebuild() {
        menu.removeAllItems()
        languageItems.removeAll()

        let strings = AppStrings.current()

        let enabled = StatusMenuToggleRow(
            title: strings.enabled,
            isOn: Preferences.enabled
        ) { [weak self] value in
            self?.onEnabledChange(value)
        }
        enabledRow = enabled
        menu.addItem(customItem(view: enabled))

        let error = NSMenuItem(title: strings.menuError, action: nil, keyEquivalent: "")
        error.isEnabled = false
        error.isHidden = !hasSystemError
        errorItem = error
        menu.addItem(error)

        menu.addItem(.separator())

        let autoSleepAfterAgentTask = NSMenuItem(
            title: strings.autoSleepAfterAgentTask,
            action: #selector(toggleAutoSleepAfterAgentTask),
            keyEquivalent: ""
        )
        autoSleepAfterAgentTask.target = self
        autoSleepAfterAgentTask.state = Preferences.autoSleepAfterAgentTask ? .on : .off
        autoSleepAfterAgentTaskItem = autoSleepAfterAgentTask
        menu.addItem(autoSleepAfterAgentTask)

        let cancelPendingAutoSleep = NSMenuItem(
            title: "",
            action: #selector(cancelPendingAutoSleep),
            keyEquivalent: ""
        )
        cancelPendingAutoSleep.target = self
        cancelPendingAutoSleepItem = cancelPendingAutoSleep
        menu.addItem(cancelPendingAutoSleep)
        updatePendingAutoSleepItem()

        menu.addItem(.separator())

        let displaySleep = NSMenuItem(
            title: strings.displaySleepOnLidClose,
            action: #selector(toggleDisplaySleep),
            keyEquivalent: ""
        )
        displaySleep.target = self
        displaySleep.state = Preferences.displaySleepOnLidClose ? .on : .off
        displaySleepItem = displaySleep
        menu.addItem(displaySleep)

        let launchAtLogin = NSMenuItem(
            title: strings.openAtLogin,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLogin.target = self
        launchAtLogin.state = Preferences.launchAtLogin ? .on : .off
        launchAtLoginItem = launchAtLogin
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())

        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: "Language")
        for language in [AppLanguage.simplifiedChinese, .japanese, .english] {
            let item = NSMenuItem(
                title: menuTitle(for: language),
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == Preferences.language ? .on : .off
            languageItems[language] = item
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: strings.quit,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func customItem(view: NSView) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view
        item.isEnabled = true
        return item
    }

    private func menuTitle(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "中文"
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else {
            return
        }
        onLanguageChange(language)
    }

    @objc private func toggleDisplaySleep() {
        onDisplaySleepChange(!Preferences.displaySleepOnLidClose)
    }

    @objc private func toggleAutoSleepAfterAgentTask() {
        onAutoSleepAfterAgentTaskChange(!Preferences.autoSleepAfterAgentTask)
    }

    @objc private func cancelPendingAutoSleep() {
        onCancelPendingAutoSleep()
    }

    @objc private func toggleLaunchAtLogin() {
        onLaunchAtLoginChange(!Preferences.launchAtLogin)
    }

    @objc private func quit() {
        onQuit()
    }

    private func updatePendingAutoSleepItem() {
        guard let item = cancelPendingAutoSleepItem else { return }
        if let pendingAutoSleepSeconds {
            item.title = AppStrings.current().cancelPendingAutoSleep(pendingAutoSleepSeconds)
            item.isHidden = false
        } else {
            item.title = ""
            item.isHidden = true
        }
    }
}

private final class StatusMenuToggleRow: NSView {
    private let toggle = NSSwitch()
    private let onChange: (Bool) -> Void
    private var trackingArea: NSTrackingArea?

    init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        let labelFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let labelWidth = ceil((title as NSString).size(withAttributes: [.font: labelFont]).width)
        let rowWidth = max(300, labelWidth + 47 + 16 + 52 + 14)
        super.init(frame: NSRect(x: 0, y: 0, width: rowWidth, height: 58))

        wantsLayer = true
        layer?.cornerRadius = 8

        let label = NSTextField(labelWithString: title)
        label.font = labelFont
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        toggle.controlSize = .large
        toggle.state = isOn ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleChanged)
        toggle.toolTip = title
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.setAccessibilityLabel(title)

        addSubview(label)
        addSubview(toggle)
        NSLayoutConstraint.activate([
            // Custom menu views already receive an outer menu inset. A 47-point
            // inner inset lines the label up with native menu item text.
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 47),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -16),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setOn(_ isOn: Bool) {
        toggle.state = isOn ? .on : .off
        setAccessibilityValue(isOn)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !toggle.frame.contains(point) else {
            super.mouseDown(with: event)
            return
        }
        toggle.state = toggle.state == .on ? .off : .on
        toggleChanged()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor
            .withAlphaComponent(0.12)
            .cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @objc private func toggleChanged() {
        let value = toggle.state == .on
        setAccessibilityValue(value)
        onChange(value)
    }
}

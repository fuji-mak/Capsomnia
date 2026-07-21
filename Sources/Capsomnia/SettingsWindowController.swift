import AppKit

enum SettingsPage {
    case initialPreferences
    case settings
    case advancedSettings
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let settingsContentWidth: CGFloat = 400
    private static let advancedContentWidth: CGFloat = 560

    private let headerIcon = NSImageView()
    private let titleLabel = brandLabel(size: 21, weight: .bold, color: Brand.text)
    private let appHeader = NSStackView()
    private let advancedHeader = NSView()
    private let advancedTitleLabel = brandLabel(size: 20, weight: .bold, color: Brand.text)
    private let backButton = NSButton()

    private let explainerCard = brandCard()
    private let explainerOnTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOnDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let explainerOffTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOffDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)

    private let preferencesHeading = brandLabel(size: 11, weight: .semibold, color: Brand.textFaint)

    private let dedicatedCapsLockModeTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let dedicatedCapsLockModeDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let dedicatedCapsLockModeToggle = LEDToggle(isOn: Preferences.dedicatedCapsLockMode)

    private let menuBarTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let menuBarDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let menuBarToggle = LEDToggle(isOn: Preferences.showMenuBarIcon)

    private let languageTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let languagePopUp = LanguagePopUpButton(
        items: AppLanguage.allCases.map { (title: $0.displayName, value: $0.rawValue) },
        selected: Preferences.language.rawValue
    )
    private let advancedSettingsButton = DisclosureButton()

    private let systemBehaviorHeading = brandLabel(
        size: 11,
        weight: .semibold,
        color: Brand.textFaint
    )
    private let openAtLoginTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let openAtLoginDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let openAtLoginToggle = LEDToggle(isOn: Preferences.launchAtLogin)
    private let displaySleepOnLidCloseTitle = brandLabel(
        size: 13,
        weight: .medium,
        color: Brand.text
    )
    private let displaySleepOnLidCloseDesc = brandLabel(
        size: 12,
        color: Brand.textDim,
        wraps: true
    )
    private let displaySleepOnLidCloseToggle = LEDToggle(
        isOn: Preferences.displaySleepOnLidClose
    )

    private let shortcutHeading = brandLabel(
        size: 11,
        weight: .semibold,
        color: Brand.textFaint
    )
    private let shortcutDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let shortcutRecorder = ShortcutRecorderButton(
        placeholder: "",
        recording: "",
        action: "",
        registrationFailed: ""
    )

    private let noteLabel = brandLabel(size: 12, color: Brand.textFaint, wraps: true)
    private let doneButton = LEDButton()

    private let rootStack = NSStackView()
    private let bodyStack = NSStackView()
    private var preferencesCard = NSView()
    private var systemCard = NSView()
    private var shortcutCard = NSView()
    private var initialPreferencesLayoutConstraints: [NSLayoutConstraint] = []
    private var settingsLayoutConstraints: [NSLayoutConstraint] = []
    private var advancedSettingsLayoutConstraints: [NSLayoutConstraint] = []

    private let onDedicatedCapsLockModeChange: (Bool) -> Void
    private let onShowMenuBarIconChange: (Bool) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onDisplaySleepOnLidCloseChange: (Bool) -> Void
    private let onKeyboardShortcutChange: (KeyboardShortcut?) -> Bool
    private let onKeyboardShortcutRecordingChange: (Bool) -> Void
    private let onFinishInitialSetup: () -> Void
    private var page: SettingsPage = .settings

    init(
        onDedicatedCapsLockModeChange: @escaping (Bool) -> Void,
        onShowMenuBarIconChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping (AppLanguage) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onDisplaySleepOnLidCloseChange: @escaping (Bool) -> Void,
        onKeyboardShortcutChange: @escaping (KeyboardShortcut?) -> Bool,
        onKeyboardShortcutRecordingChange: @escaping (Bool) -> Void,
        onFinishInitialSetup: @escaping () -> Void
    ) {
        self.onDedicatedCapsLockModeChange = onDedicatedCapsLockModeChange
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLanguageChange = onLanguageChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onDisplaySleepOnLidCloseChange = onDisplaySleepOnLidCloseChange
        self.onKeyboardShortcutChange = onKeyboardShortcutChange
        self.onKeyboardShortcutRecordingChange = onKeyboardShortcutRecordingChange
        self.onFinishInitialSetup = onFinishInitialSetup

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.settingsContentWidth, height: 480),
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
    }

    required init?(coder: NSCoder) {
        nil
    }

    func reloadText() {
        let strings = AppStrings.current()

        let isInitialSetup = page == .initialPreferences
        let isAdvancedSettings = page == .advancedSettings
        if isInitialSetup {
            window?.title = strings.welcomeTitle
        } else if isAdvancedSettings {
            window?.title = strings.advancedSettings
        } else {
            window?.title = strings.settingsTitle
        }
        titleLabel.stringValue = isInitialSetup ? strings.welcomeTitle : "Capsomnia"
        advancedTitleLabel.stringValue = strings.advancedSettings
        updateBackButtonText(strings)

        explainerOnTitle.stringValue = strings.explainerOnTitle
        explainerOnDesc.stringValue = strings.explainerOnDesc
        explainerOffTitle.stringValue = strings.explainerOffTitle
        explainerOffDesc.stringValue = strings.explainerOffDesc

        let preferencesHeadingText = isInitialSetup
            ? strings.initialPreferencesHeading
            : strings.preferencesHeading
        preferencesHeading.stringValue = preferencesHeadingText.uppercased()

        dedicatedCapsLockModeTitle.stringValue = strings.dedicatedCapsLockMode
        dedicatedCapsLockModeDesc.stringValue = strings.dedicatedCapsLockModeDesc
        menuBarTitle.stringValue = strings.showMenuBarIcon
        menuBarDesc.stringValue = strings.showMenuBarIconDesc
        languageTitle.stringValue = strings.language
        dedicatedCapsLockModeToggle.setAccessibilityLabel(strings.dedicatedCapsLockMode)
        menuBarToggle.setAccessibilityLabel(strings.showMenuBarIcon)
        languagePopUp.setAccessibilityLabel(strings.language)
        updateAdvancedSettingsButtonText(strings)

        systemBehaviorHeading.stringValue = strings.systemBehavior.uppercased()
        displaySleepOnLidCloseTitle.stringValue = strings.displaySleepOnLidClose
        displaySleepOnLidCloseDesc.stringValue = strings.displaySleepOnLidCloseDesc
        displaySleepOnLidCloseToggle.setAccessibilityLabel(strings.displaySleepOnLidClose)
        openAtLoginTitle.stringValue = strings.openAtLogin
        openAtLoginDesc.stringValue = strings.openAtLoginDesc
        openAtLoginToggle.setAccessibilityLabel(strings.openAtLogin)

        shortcutHeading.stringValue = strings.keyboardShortcut.uppercased()
        shortcutDesc.stringValue = strings.keyboardShortcutDesc
        shortcutRecorder.setStrings(
            placeholder: strings.shortcutRecorderPlaceholder,
            recording: strings.shortcutRecorderRecording,
            action: strings.shortcutRecorderAction,
            registrationFailed: strings.shortcutRegistrationFailed
        )
        shortcutRecorder.setAccessibilityLabel(strings.keyboardShortcut)
        shortcutRecorder.setAccessibilityHelp(strings.keyboardShortcutDesc)

        noteLabel.stringValue = strings.initialSettingsNote
        doneButton.title = isInitialSetup ? strings.getStarted : strings.done

        appHeader.isHidden = isAdvancedSettings

        updateValues()
    }

    func show(page: SettingsPage) {
        let wasVisible = window?.isVisible == true
        self.page = page
        applyLayout()
        reloadText()
        resizeToFit()
        if !wasVisible {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard page == .initialPreferences else { return }
        finishInitialSetup()
    }

    private func resizeToFit() {
        guard let window, let contentView = window.contentView else { return }
        let previousCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let width = page == .advancedSettings
            ? Self.advancedContentWidth
            : Self.settingsContentWidth
        let currentHeight = max(contentView.bounds.height, 1)
        window.setContentSize(NSSize(width: width, height: currentHeight))
        contentView.layoutSubtreeIfNeeded()
        let height = contentView.fittingSize.height
        window.setContentSize(NSSize(width: width, height: height))
        if window.isVisible {
            window.setFrameOrigin(NSPoint(
                x: previousCenter.x - window.frame.width / 2,
                y: previousCenter.y - window.frame.height / 2
            ))
        }
    }

    private func buildContent() {
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Brand.bg.cgColor

        headerIcon.image = BrandIcon.make(diameter: 60)
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.alignment = .center

        appHeader.addArrangedSubview(headerIcon)
        appHeader.addArrangedSubview(titleLabel)
        appHeader.orientation = .vertical
        appHeader.alignment = .centerX
        appHeader.spacing = 10
        appHeader.setCustomSpacing(14, after: headerIcon)
        appHeader.translatesAutoresizingMaskIntoConstraints = false

        buildExplainerCard()

        preferencesCard = buildPreferencesCard()
        systemCard = buildSystemCard()
        shortcutCard = buildShortcutCard()
        configureAdvancedHeader()
        configureAdvancedSettingsButton()

        doneButton.onClick = { [weak self] in self?.done() }

        configureColumn(rootStack)
        configureColumn(bodyStack)
        bodyStack.distribution = .fill
        rootStack.detachesHiddenViews = true
        rootStack.addArrangedSubview(appHeader)
        rootStack.addArrangedSubview(bodyStack)
        rootStack.setCustomSpacing(20, after: appHeader)

        contentView.addSubview(rootStack)
        window?.contentView = contentView

        initialPreferencesLayoutConstraints = [
            explainerCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            noteLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]
        settingsLayoutConstraints = [
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            advancedSettingsButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]
        advancedSettingsLayoutConstraints = [
            advancedHeader.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            systemCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            shortcutCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            appHeader.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            bodyStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])

        applyLayout()
        reloadText()
    }

    private func applyLayout() {
        NSLayoutConstraint.deactivate(
            initialPreferencesLayoutConstraints
                + settingsLayoutConstraints
                + advancedSettingsLayoutConstraints
        )
        clearArrangedSubviews(bodyStack)

        switch page {
        case .initialPreferences:
            bodyStack.addArrangedSubview(explainerCard)
            bodyStack.addArrangedSubview(preferencesHeading)
            bodyStack.addArrangedSubview(preferencesCard)
            bodyStack.addArrangedSubview(noteLabel)
            bodyStack.addArrangedSubview(doneButton)
            bodyStack.setCustomSpacing(8, after: preferencesHeading)
            NSLayoutConstraint.activate(initialPreferencesLayoutConstraints)

        case .settings:
            bodyStack.addArrangedSubview(preferencesHeading)
            bodyStack.addArrangedSubview(preferencesCard)
            bodyStack.addArrangedSubview(advancedSettingsButton)
            bodyStack.addArrangedSubview(doneButton)
            bodyStack.setCustomSpacing(8, after: preferencesHeading)
            bodyStack.setCustomSpacing(12, after: preferencesCard)
            bodyStack.setCustomSpacing(20, after: advancedSettingsButton)
            NSLayoutConstraint.activate(settingsLayoutConstraints)

        case .advancedSettings:
            bodyStack.addArrangedSubview(advancedHeader)
            bodyStack.addArrangedSubview(preferencesHeading)
            bodyStack.addArrangedSubview(preferencesCard)
            bodyStack.addArrangedSubview(systemBehaviorHeading)
            bodyStack.addArrangedSubview(systemCard)
            bodyStack.addArrangedSubview(shortcutHeading)
            bodyStack.addArrangedSubview(shortcutCard)
            bodyStack.setCustomSpacing(24, after: advancedHeader)
            bodyStack.setCustomSpacing(8, after: preferencesHeading)
            bodyStack.setCustomSpacing(22, after: preferencesCard)
            bodyStack.setCustomSpacing(8, after: systemBehaviorHeading)
            bodyStack.setCustomSpacing(22, after: systemCard)
            bodyStack.setCustomSpacing(8, after: shortcutHeading)
            NSLayoutConstraint.activate(advancedSettingsLayoutConstraints)
        }
    }

    private func configureColumn(_ stack: NSStackView) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
    }

    private func clearArrangedSubviews(_ stack: NSStackView) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
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

        dedicatedCapsLockModeToggle.onToggle = { [weak self] enabled in
            self?.onDedicatedCapsLockModeChange(enabled)
            self?.updateValues()
        }
        menuBarToggle.onToggle = { [weak self] enabled in
            self?.onShowMenuBarIconChange(enabled)
            self?.updateValues()
        }
        languagePopUp.onSelect = { [weak self] rawValue in
            guard let language = AppLanguage(rawValue: rawValue) else { return }
            self?.onLanguageChange(language)
        }

        let dedicatedCapsLockModeRow = settingRow(
            title: dedicatedCapsLockModeTitle,
            desc: dedicatedCapsLockModeDesc,
            accessory: dedicatedCapsLockModeToggle
        )
        let menuBarRow = settingRow(title: menuBarTitle, desc: menuBarDesc, accessory: menuBarToggle)
        let languageRow = settingRow(title: languageTitle, desc: nil, accessory: languagePopUp)

        let divider1 = brandDivider()
        let divider2 = brandDivider()

        let inner = NSStackView(views: [
            menuBarRow,
            divider1,
            dedicatedCapsLockModeRow,
            divider2,
            languageRow
        ])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 14
        inner.detachesHiddenViews = true
        inner.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        for row in [
            menuBarRow,
            divider1,
            dedicatedCapsLockModeRow,
            divider2,
            languageRow
        ] {
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

    private func buildSystemCard() -> NSView {
        displaySleepOnLidCloseToggle.onToggle = { [weak self] enabled in
            self?.onDisplaySleepOnLidCloseChange(enabled)
            self?.updateValues()
        }
        openAtLoginToggle.onToggle = { [weak self] enabled in
            self?.onLaunchAtLoginChange(enabled)
            self?.updateValues()
        }

        let displayRow = settingRow(
            title: displaySleepOnLidCloseTitle,
            desc: displaySleepOnLidCloseDesc,
            accessory: displaySleepOnLidCloseToggle
        )
        let openAtLoginRow = settingRow(
            title: openAtLoginTitle,
            desc: openAtLoginDesc,
            accessory: openAtLoginToggle
        )
        let divider = brandDivider()

        let card = brandCard()
        let stack = NSStackView(views: [displayRow, divider, openAtLoginRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            displayRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            openAtLoginRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return card
    }

    private func buildShortcutCard() -> NSView {
        shortcutRecorder.onShortcutChange = onKeyboardShortcutChange
        shortcutRecorder.onRecordingChange = onKeyboardShortcutRecordingChange
        shortcutDesc.setContentHuggingPriority(.required, for: .vertical)

        let stack = NSStackView(views: [
            shortcutDesc,
            shortcutRecorder
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(14, after: shortcutDesc)

        let card = brandCard()
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 17),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            shortcutDesc.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutRecorder.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return card
    }

    private func updateValues() {
        dedicatedCapsLockModeToggle.setOn(Preferences.dedicatedCapsLockMode)
        menuBarToggle.setOn(Preferences.showMenuBarIcon)
        languagePopUp.setSelected(Preferences.language.rawValue)
        displaySleepOnLidCloseToggle.setOn(Preferences.displaySleepOnLidClose)
        openAtLoginToggle.setOn(Preferences.launchAtLogin)
        shortcutRecorder.setShortcut(Preferences.keyboardShortcut)
    }

    private func configureAdvancedHeader() {
        advancedHeader.translatesAutoresizingMaskIntoConstraints = false

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isBordered = false
        backButton.image = NSImage(
            systemSymbolName: "chevron.backward",
            accessibilityDescription: nil
        )
        backButton.imagePosition = .imageLeading
        backButton.contentTintColor = Brand.textDim
        backButton.font = .systemFont(ofSize: 13, weight: .medium)
        backButton.target = self
        backButton.action = #selector(showBasicSettings)
        backButton.focusRingType = .exterior

        advancedTitleLabel.alignment = .center
        advancedTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        advancedHeader.addSubview(backButton)
        advancedHeader.addSubview(advancedTitleLabel)
        NSLayoutConstraint.activate([
            advancedHeader.heightAnchor.constraint(equalToConstant: 32),
            backButton.leadingAnchor.constraint(equalTo: advancedHeader.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: advancedHeader.centerYAnchor),
            advancedTitleLabel.centerXAnchor.constraint(equalTo: advancedHeader.centerXAnchor),
            advancedTitleLabel.centerYAnchor.constraint(equalTo: advancedHeader.centerYAnchor),
            advancedTitleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: backButton.trailingAnchor,
                constant: 16
            )
        ])
    }

    private func updateBackButtonText(_ strings: AppStrings) {
        backButton.attributedTitle = NSAttributedString(
            string: strings.settingsTitle,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: Brand.textDim
            ]
        )
        backButton.setAccessibilityLabel(strings.settingsTitle)
    }

    private func configureAdvancedSettingsButton() {
        advancedSettingsButton.onClick = { [weak self] in
            self?.showAdvancedSettings()
        }
    }

    private func updateAdvancedSettingsButtonText(_ strings: AppStrings) {
        advancedSettingsButton.setStrings(
            title: strings.advancedSettings,
            subtitle: strings.advancedSettingsDesc
        )
    }

    func showAdvancedSettings() {
        show(page: .advancedSettings)
    }

    @objc private func showBasicSettings() {
        show(page: .settings)
    }

    private func finishInitialSetup() {
        page = .settings
        onShowMenuBarIconChange(menuBarToggle.isOn)
        onDedicatedCapsLockModeChange(dedicatedCapsLockModeToggle.isOn)
        if let language = AppLanguage(rawValue: languagePopUp.selectedValue) {
            onLanguageChange(language)
        }
        onFinishInitialSetup()
    }

    private func done() {
        if page == .initialPreferences {
            finishInitialSetup()
        }
        close()
    }
}

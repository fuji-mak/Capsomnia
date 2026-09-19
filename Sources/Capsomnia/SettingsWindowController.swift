import AppKit

enum SettingsPage {
    case initialPreferences
    case settings
    case advancedSettings
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let settingsContentWidth: CGFloat = 400
    private static let advancedContentWidth: CGFloat = 920
    private static let advancedColumnSpacing: CGFloat = 20

    private let headerIcon = NSImageView()
    private let titleLabel = brandLabel(size: 21, weight: .bold, color: Brand.text)
    private let appHeader = NSStackView()
    private let advancedHeader = NSView()
    private let advancedTitleLabel = brandLabel(size: 20, weight: .bold, color: Brand.text)
    private let backButton = NSButton()
    private let toolsDownloadButton = DisclosureButton(symbolName: "arrow.down.to.line", height: 44)

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

    private let autoOffControl = AutoOffTimerControl(minutes: Preferences.autoOffMinutes)

    private let systemBehaviorHeading = brandLabel(
        size: 11,
        weight: .semibold,
        color: Brand.textFaint
    )
    private let openAtLoginTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let openAtLoginDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let openAtLoginToggle = LEDToggle(isOn: Preferences.launchAtLogin)
    private let keepDisplayAwakeTitle = brandLabel(
        size: 13,
        weight: .medium,
        color: Brand.text
    )
    private let keepDisplayAwakeDesc = brandLabel(
        size: 12,
        color: Brand.textDim,
        wraps: true
    )
    private let keepDisplayAwakeToggle = LEDToggle(
        isOn: Preferences.keepDisplayAwake
    )
    private let externalCapsLockOffTitle = brandLabel(
        size: 13,
        weight: .medium,
        color: Brand.text
    )
    private let externalCapsLockOffDesc = brandLabel(
        size: 12,
        color: Brand.textDim,
        wraps: true
    )
    private let externalCapsLockOffToggle = LEDToggle(
        isOn: Preferences.ignoreExternalCapsLockOffWhileLidClosed
    )
    private let hideIndicatorTitle = brandLabel(
        size: 13,
        weight: .medium,
        color: Brand.text
    )
    private let hideIndicatorDesc = brandLabel(
        size: 12,
        color: Brand.textDim,
        wraps: true
    )
    private let hideIndicatorRestartNote = brandLabel(
        size: 12,
        color: Brand.led,
        wraps: true
    )
    // The real value arrives through capsLockIndicatorStateProvider in
    // updateValues(); property initializers run before init parameters exist.
    private let hideIndicatorToggle = LEDToggle(isOn: false)
    private let automaticUpdateChecksTitle = brandLabel(
        size: 13,
        weight: .medium,
        color: Brand.text
    )
    private let automaticUpdateChecksDesc = brandLabel(
        size: 12,
        color: Brand.textDim,
        wraps: true
    )
    private let automaticUpdateChecksToggle = LEDToggle(
        isOn: Preferences.automaticUpdateChecks
    )

    private let updateHeading = brandLabel(size: 11, weight: .semibold, color: Brand.textFaint)
    private let updateVersionLabel = brandLabel(size: 13, weight: .semibold, color: Brand.led, wraps: true)
    private let updateCurrentVersionLabel = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let updateButton = LEDButton(height: 30)
    private let releaseNotesButton = NSButton()
    private let updateVersionRow = NSStackView()
    private let updateActionRow = NSStackView()
    private var updateCard = NSView()
    private let updateCardStack = NSStackView()
    private var automaticUpdateChecksRow = NSView()
    private let updateDivider = brandDivider()
    private var updateRowWidthConstraints: [NSLayoutConstraint] = []
    private var updateCardWidthConstraint: NSLayoutConstraint?
    private var availableUpdateVersion: String?
    private let currentVersion: String
    private let onUpdate: (String) -> Void
    private let onReleaseNotes: (String) -> Void
    private let onToolsDownload: () -> Void
    private let autoOffDescriptionProvider: () -> String?

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
    private let advancedColumns = NSStackView()
    private let advancedLeftColumn = NSStackView()
    private let advancedRightColumn = NSStackView()
    private let advancedRightSpacer = NSView()
    private var preferencesCard = NSView()
    private var keepDisplayAwakeCard = NSView()
    private var systemCard = NSView()
    private var shortcutCard = NSView()
    private var autoOffCard = NSView()
    private var initialPreferencesLayoutConstraints: [NSLayoutConstraint] = []
    private var settingsLayoutConstraints: [NSLayoutConstraint] = []
    private var advancedSettingsLayoutConstraints: [NSLayoutConstraint] = []

    private let onDedicatedCapsLockModeChange: (Bool) -> Void
    private let onShowMenuBarIconChange: (Bool) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onKeepDisplayAwakeChange: (Bool) -> Void
    private let onIgnoreExternalCapsLockOffWhileLidClosedChange: (Bool) -> Void
    private let onHideCapsLockIndicatorChange: (Bool) -> Void
    private let capsLockIndicatorStateProvider: () -> CapsLockIndicatorDisplayState
    private let onAutoOffMinutesChange: (Int) -> Void
    private let onAutoOffRestart: () -> Void
    private let autoOffDisplayProvider: () -> AutoOffDisplayState
    private let onKeyboardShortcutChange: (KeyboardShortcut?) -> Bool
    private let onKeyboardShortcutRecordingChange: (Bool) -> Void
    private let onAutomaticUpdateChecksChange: (Bool) -> Void
    private let onFinishInitialSetup: () -> Void
    private var page: SettingsPage = .settings

    init(
        onDedicatedCapsLockModeChange: @escaping (Bool) -> Void,
        onShowMenuBarIconChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping (AppLanguage) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onKeepDisplayAwakeChange: @escaping (Bool) -> Void,
        onIgnoreExternalCapsLockOffWhileLidClosedChange: @escaping (Bool) -> Void,
        onHideCapsLockIndicatorChange: @escaping (Bool) -> Void,
        capsLockIndicatorStateProvider: @escaping () -> CapsLockIndicatorDisplayState,
        onAutoOffMinutesChange: @escaping (Int) -> Void,
        onAutoOffRestart: @escaping () -> Void,
        autoOffDisplayProvider: @escaping () -> AutoOffDisplayState,
        onKeyboardShortcutChange: @escaping (KeyboardShortcut?) -> Bool,
        onKeyboardShortcutRecordingChange: @escaping (Bool) -> Void,
        onAutomaticUpdateChecksChange: @escaping (Bool) -> Void,
        onFinishInitialSetup: @escaping () -> Void,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        onUpdate: @escaping (String) -> Void = { _ in },
        onReleaseNotes: @escaping (String) -> Void = { _ in },
        onToolsDownload: @escaping () -> Void = {},
        autoOffDescriptionProvider: @escaping () -> String? = { nil }
    ) {
        self.onDedicatedCapsLockModeChange = onDedicatedCapsLockModeChange
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLanguageChange = onLanguageChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onKeepDisplayAwakeChange = onKeepDisplayAwakeChange
        self.onIgnoreExternalCapsLockOffWhileLidClosedChange = onIgnoreExternalCapsLockOffWhileLidClosedChange
        self.onHideCapsLockIndicatorChange = onHideCapsLockIndicatorChange
        self.capsLockIndicatorStateProvider = capsLockIndicatorStateProvider
        self.onAutoOffMinutesChange = onAutoOffMinutesChange
        self.onAutoOffRestart = onAutoOffRestart
        self.autoOffDisplayProvider = autoOffDisplayProvider
        self.onKeyboardShortcutChange = onKeyboardShortcutChange
        self.onKeyboardShortcutRecordingChange = onKeyboardShortcutRecordingChange
        self.onAutomaticUpdateChecksChange = onAutomaticUpdateChecksChange
        self.onFinishInitialSetup = onFinishInitialSetup
        self.currentVersion = currentVersion
        self.onUpdate = onUpdate
        self.onReleaseNotes = onReleaseNotes
        self.onToolsDownload = onToolsDownload
        self.autoOffDescriptionProvider = autoOffDescriptionProvider

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
        keepDisplayAwakeTitle.stringValue = strings.keepDisplayAwake
        keepDisplayAwakeDesc.stringValue = strings.keepDisplayAwakeDesc
        keepDisplayAwakeToggle.setAccessibilityLabel(strings.keepDisplayAwake)
        externalCapsLockOffTitle.stringValue = strings.ignoreExternalCapsLockOffWhileLidClosed
        externalCapsLockOffDesc.stringValue = strings.ignoreExternalCapsLockOffWhileLidClosedDesc
        externalCapsLockOffToggle.setAccessibilityLabel(strings.ignoreExternalCapsLockOffWhileLidClosed)
        hideIndicatorTitle.stringValue = strings.hideCapsLockIndicator
        hideIndicatorDesc.stringValue = strings.hideCapsLockIndicatorDesc
        hideIndicatorRestartNote.stringValue = strings.hideCapsLockIndicatorRestartNote
        hideIndicatorToggle.setAccessibilityLabel(strings.hideCapsLockIndicator)
        openAtLoginTitle.stringValue = strings.openAtLogin
        openAtLoginDesc.stringValue = strings.openAtLoginDesc
        openAtLoginToggle.setAccessibilityLabel(strings.openAtLogin)
        automaticUpdateChecksTitle.stringValue = strings.automaticUpdateChecks
        automaticUpdateChecksDesc.stringValue = strings.automaticUpdateChecksDesc
        automaticUpdateChecksToggle.setAccessibilityLabel(strings.automaticUpdateChecks)

        autoOffControl.setStrings(
            desc: autoOffDescriptionProvider() ?? strings.autoOffTimerDesc,
            off: strings.autoOffOff,
            custom: strings.autoOffCustom,
            turnsOffIn: strings.autoOffTurnsOffIn,
            hours: strings.autoOffHours,
            minutesUnit: strings.autoOffMinutesUnit,
            restart: strings.autoOffRestart
        )
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

        updateToolsDownloading(toolsDownloading)
        updateHeading.stringValue = strings.updatesHeading.uppercased()
        updateVersionLabel.stringValue = availableUpdateVersion.map { String(format: strings.updateAvailableVersionFormat, $0) } ?? ""
        updateCurrentVersionLabel.stringValue = String(format: strings.updateCurrentVersionFormat, currentVersion)
        updateButton.title = strings.updateAction
        updateButton.toolTip = strings.updateDownloadAndInstall
        updateButton.setAccessibilityHelp(strings.updateDownloadAndInstall)
        releaseNotesButton.attributedTitle = NSAttributedString(
            string: strings.releaseNotes,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: Brand.textDim,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        releaseNotesButton.setAccessibilityLabel(strings.releaseNotes)
        layoutUpdateRows()

        noteLabel.stringValue = strings.initialSettingsNote
        doneButton.title = isInitialSetup ? strings.getStarted : strings.done

        appHeader.isHidden = isAdvancedSettings

        updateValues()
    }

    func updateAvailableVersion(_ version: String?) {
        guard availableUpdateVersion != version else { return }
        availableUpdateVersion = version
        reloadText()
        if page == .advancedSettings {
            applyLayout()
            resizeToFit()
        }
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
        if page == .settings {
            autoOffControl.startDisplayUpdates()
        } else {
            autoOffControl.dismissCustomEditor()
            autoOffControl.stopDisplayUpdates()
        }
    }

    func windowWillClose(_ notification: Notification) {
        // The controller and window are reused after closing, so transient
        // recording state must not survive into the next presentation.
        shortcutRecorder.cancelRecording()
        autoOffControl.dismissCustomEditor()
        autoOffControl.stopDisplayUpdates()
        guard page == .initialPreferences else { return }
        finishInitialSetup()
    }

    private var toolsDownloading = false
    private var toolsMessage: String?

    func updateToolsDownloading(_ downloading: Bool) {
        toolsDownloading = downloading
        if downloading { toolsMessage = nil }
        toolsDownloadButton.isEnabled = !downloading
        toolsDownloadButton.setTitle(toolsMessage ?? (downloading ? ToolsDownloadText.current.installing : ToolsDownloadText.current.entryTitle))
        toolsDownloadButton.toolTip = ToolsDownloadText.current.entryDescription
        toolsDownloadButton.setAccessibilityHelp(ToolsDownloadText.current.entryDescription)
    }

    func updateToolsMessage(_ message: String?) {
        toolsMessage = message
        toolsDownloadButton.setTitle(message ?? (toolsDownloading ? ToolsDownloadText.current.installing : ToolsDownloadText.current.entryTitle))
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
        keepDisplayAwakeCard = buildKeepDisplayAwakeCard()
        systemCard = buildSystemCard()
        shortcutCard = buildShortcutCard()
        updateCard = buildUpdateCard()
        autoOffCard = buildAutoOffCard()
        configureAdvancedHeader()
        configureAdvancedSettingsButton()

        doneButton.onClick = { [weak self] in self?.done() }

        configureColumn(rootStack)
        configureColumn(bodyStack)
        configureColumn(advancedLeftColumn)
        configureColumn(advancedRightColumn)
        advancedColumns.orientation = .horizontal
        advancedColumns.alignment = .top
        advancedColumns.distribution = .fillEqually
        advancedColumns.spacing = Self.advancedColumnSpacing
        advancedColumns.translatesAutoresizingMaskIntoConstraints = false
        advancedColumns.addArrangedSubview(advancedLeftColumn)
        advancedColumns.addArrangedSubview(advancedRightColumn)
        advancedRightSpacer.translatesAutoresizingMaskIntoConstraints = false
        advancedRightSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        advancedRightSpacer.setContentHuggingPriority(
            NSLayoutConstraint.Priority(1),
            for: .vertical
        )
        bodyStack.distribution = .fill
        rootStack.detachesHiddenViews = true
        rootStack.addArrangedSubview(appHeader)
        rootStack.addArrangedSubview(bodyStack)
        rootStack.setCustomSpacing(20, after: appHeader)

        toolsDownloadButton.onClick = { [weak self] in self?.onToolsDownload() }
        updateToolsDownloading(toolsDownloading)

        contentView.addSubview(rootStack)
        window?.contentView = contentView

        initialPreferencesLayoutConstraints = [
            explainerCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            noteLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]
        settingsLayoutConstraints = [
            keepDisplayAwakeCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            autoOffCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            advancedSettingsButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]
        updateCardWidthConstraint = updateCard.widthAnchor.constraint(equalTo: advancedRightColumn.widthAnchor)
        advancedSettingsLayoutConstraints = [
            advancedHeader.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            advancedColumns.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            preferencesCard.widthAnchor.constraint(equalTo: advancedLeftColumn.widthAnchor),
            systemCard.widthAnchor.constraint(equalTo: advancedLeftColumn.widthAnchor),
            shortcutCard.widthAnchor.constraint(equalTo: advancedRightColumn.widthAnchor),
            toolsDownloadButton.widthAnchor.constraint(equalTo: advancedRightColumn.widthAnchor),
            advancedRightColumn.bottomAnchor.constraint(equalTo: advancedColumns.bottomAnchor),
            toolsDownloadButton.bottomAnchor.constraint(equalTo: advancedRightColumn.bottomAnchor)
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
        updateCardWidthConstraint?.isActive = false
        NSLayoutConstraint.deactivate(
            initialPreferencesLayoutConstraints
                + settingsLayoutConstraints
                + advancedSettingsLayoutConstraints
        )
        clearArrangedSubviews(bodyStack)
        clearArrangedSubviews(advancedLeftColumn)
        clearArrangedSubviews(advancedRightColumn)

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
            bodyStack.addArrangedSubview(autoOffCard)
            bodyStack.addArrangedSubview(keepDisplayAwakeCard)
            bodyStack.addArrangedSubview(advancedSettingsButton)
            bodyStack.addArrangedSubview(doneButton)
            bodyStack.setCustomSpacing(20, after: autoOffCard)
            bodyStack.setCustomSpacing(20, after: keepDisplayAwakeCard)
            bodyStack.setCustomSpacing(20, after: advancedSettingsButton)
            NSLayoutConstraint.activate(settingsLayoutConstraints)

        case .advancedSettings:
            bodyStack.addArrangedSubview(advancedHeader)
            bodyStack.addArrangedSubview(advancedColumns)

            advancedLeftColumn.addArrangedSubview(preferencesHeading)
            advancedLeftColumn.addArrangedSubview(preferencesCard)
            advancedLeftColumn.addArrangedSubview(systemBehaviorHeading)
            advancedLeftColumn.addArrangedSubview(systemCard)
            advancedLeftColumn.setCustomSpacing(8, after: preferencesHeading)
            advancedLeftColumn.setCustomSpacing(22, after: preferencesCard)
            advancedLeftColumn.setCustomSpacing(8, after: systemBehaviorHeading)

            advancedRightColumn.addArrangedSubview(shortcutHeading)
            advancedRightColumn.addArrangedSubview(shortcutCard)
            advancedRightColumn.addArrangedSubview(updateHeading)
            advancedRightColumn.addArrangedSubview(updateCard)
            advancedRightColumn.addArrangedSubview(advancedRightSpacer)
            advancedRightColumn.addArrangedSubview(toolsDownloadButton)
            advancedRightColumn.setCustomSpacing(16, after: updateCard)
            advancedRightColumn.setCustomSpacing(0, after: advancedRightSpacer)
            advancedRightColumn.setCustomSpacing(22, after: shortcutCard)
            advancedRightColumn.setCustomSpacing(8, after: updateHeading)
            updateCardWidthConstraint?.isActive = true
            advancedRightColumn.setCustomSpacing(8, after: shortcutHeading)

            bodyStack.setCustomSpacing(24, after: advancedHeader)
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

    private func buildKeepDisplayAwakeCard() -> NSView {
        keepDisplayAwakeToggle.onToggle = { [weak self] enabled in
            self?.onKeepDisplayAwakeChange(enabled)
            self?.updateValues()
        }
        let row = settingRow(
            title: keepDisplayAwakeTitle,
            desc: keepDisplayAwakeDesc,
            accessory: keepDisplayAwakeToggle
        )
        let card = brandCard()
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func buildSystemCard() -> NSView {
        externalCapsLockOffToggle.onToggle = { [weak self] enabled in
            self?.onIgnoreExternalCapsLockOffWhileLidClosedChange(enabled)
            self?.updateValues()
        }
        hideIndicatorToggle.onToggle = { [weak self] enabled in
            self?.onHideCapsLockIndicatorChange(enabled)
            self?.updateValues()
        }
        openAtLoginToggle.onToggle = { [weak self] enabled in
            self?.onLaunchAtLoginChange(enabled)
            self?.updateValues()
        }
        let externalCapsLockOffRow = settingRow(
            title: externalCapsLockOffTitle,
            desc: externalCapsLockOffDesc,
            accessory: externalCapsLockOffToggle
        )
        let hideIndicatorRow = settingRow(
            title: hideIndicatorTitle,
            desc: hideIndicatorDesc,
            accessory: hideIndicatorToggle
        )
        let openAtLoginRow = settingRow(
            title: openAtLoginTitle,
            desc: openAtLoginDesc,
            accessory: openAtLoginToggle
        )
        let card = brandCard()
        let rows: [NSView] = [
            externalCapsLockOffRow, brandDivider(),
            hideIndicatorRow, hideIndicatorRestartNote, brandDivider(),
            openAtLoginRow
        ]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.detachesHiddenViews = true
        stack.setCustomSpacing(6, after: hideIndicatorRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        for row in rows {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
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

    private func buildUpdateCard() -> NSView {
        automaticUpdateChecksToggle.onToggle = { [weak self] enabled in
            self?.onAutomaticUpdateChecksChange(enabled)
            self?.updateValues()
        }
        automaticUpdateChecksRow = settingRow(
            title: automaticUpdateChecksTitle,
            desc: automaticUpdateChecksDesc,
            accessory: automaticUpdateChecksToggle
        )
        updateButton.onClick = { [weak self] in
            guard let self, let version = self.availableUpdateVersion else { return }
            self.onUpdate(version)
        }
        releaseNotesButton.isBordered = false
        releaseNotesButton.alignment = .left
        releaseNotesButton.translatesAutoresizingMaskIntoConstraints = false
        releaseNotesButton.target = self
        releaseNotesButton.action = #selector(openReleaseNotes)
        updateVersionRow.orientation = .horizontal
        updateVersionRow.alignment = .firstBaseline
        updateVersionRow.spacing = 8
        updateVersionRow.translatesAutoresizingMaskIntoConstraints = false
        updateVersionRow.addArrangedSubview(updateVersionLabel)
        updateVersionRow.addArrangedSubview(releaseNotesButton)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        updateVersionRow.addArrangedSubview(spacer)
        updateVersionLabel.setContentHuggingPriority(.required, for: .horizontal)
        releaseNotesButton.setContentHuggingPriority(.required, for: .horizontal)
        releaseNotesButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        let versionDetails = NSStackView(views: [updateVersionRow, updateCurrentVersionLabel])
        configureColumn(versionDetails)
        versionDetails.spacing = 3
        versionDetails.setHuggingPriority(.defaultLow, for: .horizontal)
        updateVersionRow.widthAnchor.constraint(equalTo: versionDetails.widthAnchor).isActive = true
        updateCurrentVersionLabel.widthAnchor.constraint(equalTo: versionDetails.widthAnchor).isActive = true
        updateButton.setContentHuggingPriority(.required, for: .horizontal)
        updateButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        updateActionRow.orientation = .horizontal
        updateActionRow.alignment = .centerY
        updateActionRow.spacing = 16
        updateActionRow.translatesAutoresizingMaskIntoConstraints = false
        updateActionRow.addArrangedSubview(versionDetails)
        updateActionRow.addArrangedSubview(updateButton)
        updateButton.trailingAnchor.constraint(equalTo: updateActionRow.trailingAnchor).isActive = true
        configureColumn(updateCardStack)
        updateCardStack.spacing = 14
        let card = brandCard()
        card.addSubview(updateCardStack)
        NSLayoutConstraint.activate([
            updateCardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            updateCardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            updateCardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            updateCardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    @objc private func openReleaseNotes() {
        guard let version = availableUpdateVersion else { return }
        onReleaseNotes(version)
    }

    private func layoutUpdateRows() {
        NSLayoutConstraint.deactivate(updateRowWidthConstraints)
        clearArrangedSubviews(updateCardStack)
        var rows: [NSView] = [automaticUpdateChecksRow]
        if availableUpdateVersion != nil {
            rows += [updateDivider, updateActionRow]
        }
        rows.forEach { updateCardStack.addArrangedSubview($0) }
        updateRowWidthConstraints = rows.map {
            $0.widthAnchor.constraint(equalTo: updateCardStack.widthAnchor)
        }
        NSLayoutConstraint.activate(updateRowWidthConstraints)
    }

    private func buildAutoOffCard() -> NSView {
        autoOffControl.onMinutesChange = { [weak self] minutes in
            self?.onAutoOffMinutesChange(minutes)
        }
        autoOffControl.displayProvider = autoOffDisplayProvider
        autoOffControl.onRestart = { [weak self] in
            self?.onAutoOffRestart()
        }

        let card = brandCard()
        card.addSubview(autoOffControl)
        NSLayoutConstraint.activate([
            autoOffControl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            autoOffControl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            autoOffControl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            autoOffControl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func updateValues() {
        dedicatedCapsLockModeToggle.setOn(Preferences.dedicatedCapsLockMode)
        menuBarToggle.setOn(Preferences.showMenuBarIcon)
        languagePopUp.setSelected(Preferences.language.rawValue)
        keepDisplayAwakeToggle.setOn(Preferences.keepDisplayAwake)
        externalCapsLockOffToggle.setOn(Preferences.ignoreExternalCapsLockOffWhileLidClosed)
        let indicatorState = capsLockIndicatorStateProvider()
        hideIndicatorToggle.setOn(indicatorState.hidden)
        let noteWasHidden = hideIndicatorRestartNote.isHidden
        hideIndicatorRestartNote.isHidden = !indicatorState.restartPending
        if noteWasHidden != hideIndicatorRestartNote.isHidden, window?.isVisible == true {
            resizeToFit()
        }
        openAtLoginToggle.setOn(Preferences.launchAtLogin)
        automaticUpdateChecksToggle.setOn(Preferences.automaticUpdateChecks)
        shortcutRecorder.setShortcut(Preferences.keyboardShortcut)
        autoOffControl.setMinutes(Preferences.autoOffMinutes)
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
        advancedSettingsButton.setTitle(strings.advancedSettings)
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

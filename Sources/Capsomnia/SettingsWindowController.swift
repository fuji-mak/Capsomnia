import AppKit

private final class HotspotSettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

enum SettingsPage {
    case initialPreferences
    case settings
    case advancedSettings
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
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

    private var explainerCard = NSView()
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
    private let keepHotspotAliveTitle = brandLabel(
        size: 13,
        weight: .medium,
        color: Brand.text
    )
    private let keepHotspotAliveDesc = brandLabel(
        size: 12,
        color: Brand.textDim,
        wraps: true
    )
    private let keepHotspotAliveToggle = LEDToggle(
        isOn: Preferences.keepHotspotAlive
    )
    private let hotspotTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let hotspotDescription = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let hotspotToggle = LEDToggle(isOn: Preferences.autoConnectHotspot)
    private let hotspotSSIDField = NSTextField()
    private let hotspotPasswordField = NSSecureTextField()
    private let hotspotSaveButton = NSButton()
    private let hotspotForgetButton = NSButton()
    private let hotspotLocationButton = NSButton()
    private let hotspotLocationSettingsButton = NSButton()
    private let hotspotWiFiSettingsButton = NSButton()
    private let hotspotStatusLabel = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let hotspotEditLabel = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let instantHotspotDescription = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private var hotspotCard = NSView()
    private let hotspotEntryButton = DisclosureButton()
    private var hotspotWindow: NSWindow?
    private var hotspotEditInFlight = false
    private let onHotspotConfigurationChange: (Bool, String) -> Void
    private let onHotspotPasswordSave: (String, String, @escaping (Bool) -> Void) -> Void
    private let onHotspotPasswordForget: (String, @escaping (Bool) -> Void) -> Void
    private let onHotspotLocationRequest: () -> Void
    private let hotspotStatusProvider: () -> HotspotReconnectStatus

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
    private let onKeepHotspotAliveChange: (Bool) -> Void
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
        onKeepHotspotAliveChange: @escaping (Bool) -> Void,
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
        autoOffDescriptionProvider: @escaping () -> String? = { nil },
        onHotspotConfigurationChange: @escaping (Bool, String) -> Void = { _, _ in },
        onHotspotPasswordSave: @escaping (String, String, @escaping (Bool) -> Void) -> Void = { _, _, done in done(false) },
        onHotspotPasswordForget: @escaping (String, @escaping (Bool) -> Void) -> Void = { _, done in done(false) },
        onHotspotLocationRequest: @escaping () -> Void = {},
        hotspotStatusProvider: @escaping () -> HotspotReconnectStatus = { .disabled }
    ) {
        self.onHotspotConfigurationChange = onHotspotConfigurationChange
        self.onHotspotPasswordSave = onHotspotPasswordSave
        self.onHotspotPasswordForget = onHotspotPasswordForget
        self.onHotspotLocationRequest = onHotspotLocationRequest
        self.hotspotStatusProvider = hotspotStatusProvider
        self.onDedicatedCapsLockModeChange = onDedicatedCapsLockModeChange
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLanguageChange = onLanguageChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onKeepDisplayAwakeChange = onKeepDisplayAwakeChange
        self.onKeepHotspotAliveChange = onKeepHotspotAliveChange
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
        let hotspot = HotspotStrings.current()
        hotspotEntryButton.setTitle(hotspot.title)
        hotspotWindow?.title = hotspot.title
        hotspotTitle.stringValue = hotspot.title
        hotspotDescription.stringValue = hotspot.description
        hotspotToggle.setAccessibilityLabel(hotspot.title)
        hotspotSSIDField.placeholderString = hotspot.ssid
        hotspotSSIDField.setAccessibilityLabel(hotspot.ssid)
        hotspotPasswordField.placeholderString = hotspot.password
        hotspotPasswordField.setAccessibilityLabel(hotspot.password)
        hotspotSaveButton.title = hotspot.save
        hotspotForgetButton.title = hotspot.forget
        hotspotLocationButton.title = hotspot.requestLocation
        hotspotLocationSettingsButton.title = hotspot.locationSettings
        hotspotWiFiSettingsButton.title = hotspot.wifiSettings
        instantHotspotDescription.stringValue = hotspot.instantHotspot
        updateHotspotReconnectStatus(hotspotStatusProvider())

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
        keepHotspotAliveTitle.stringValue = strings.keepHotspotAlive
        keepHotspotAliveDesc.stringValue = strings.keepHotspotAliveDesc
        keepHotspotAliveToggle.setAccessibilityLabel(strings.keepHotspotAlive)
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
        hotspotPasswordField.stringValue = ""
        if notification.object as? NSWindow === hotspotWindow { return }
        hotspotWindow?.close()
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

        explainerCard = buildExplainerCard()

        preferencesCard = buildPreferencesCard()
        keepDisplayAwakeCard = buildKeepDisplayAwakeCard()
        systemCard = buildSystemCard()
        hotspotCard = buildHotspotCard()
        hotspotEntryButton.onClick = { [weak self] in self?.showHotspotSettings() }
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
            hotspotEntryButton.widthAnchor.constraint(equalTo: advancedRightColumn.widthAnchor),
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

            advancedRightColumn.addArrangedSubview(hotspotEntryButton)
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

    private func cardRows(_ rows: [NSView], spacing: CGFloat = 14) -> NSStackView {
        let stack = NSStackView(views: rows)
        configureColumn(stack)
        stack.spacing = spacing
        stack.detachesHiddenViews = true
        NSLayoutConstraint.activate(rows.map {
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor)
        })
        return stack
    }

    private func settingsCard(
        _ content: NSView,
        insets: NSEdgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    ) -> NSView {
        let card = brandCard()
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: insets.left),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -insets.right),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: insets.top),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -insets.bottom)
        ])
        return card
    }

    private func buildExplainerCard() -> NSView {
        let onRow = explainerRow(dot: brandStatusDot(on: true), title: explainerOnTitle, desc: explainerOnDesc)
        let offRow = explainerRow(dot: brandStatusDot(on: false), title: explainerOffTitle, desc: explainerOffDesc)
        return settingsCard(cardRows([onRow, offRow]))
    }

    private func buildPreferencesCard() -> NSView {
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

        return settingsCard(cardRows([
            menuBarRow,
            brandDivider(),
            dedicatedCapsLockModeRow,
            brandDivider(),
            languageRow
        ]))
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
        let displayRow = settingRow(
            title: keepDisplayAwakeTitle,
            desc: keepDisplayAwakeDesc,
            accessory: keepDisplayAwakeToggle
        )
        let stack = cardRows([displayRow])
        return settingsCard(stack, insets: NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18))
    }

    func updateHotspotReconnectStatus(_ status: HotspotReconnectStatus) {
        hotspotStatusLabel.stringValue = HotspotStrings.current().status(status)
    }

    func showHotspotSettings() {
        if hotspotWindow == nil {
            let available = window?.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? 720
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: min(600, available - 80)),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.backgroundColor = Brand.bg
            panel.appearance = NSAppearance(named: .darkAqua)
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.drawsBackground = false
            scroll.translatesAutoresizingMaskIntoConstraints = false
            let document = HotspotSettingsDocumentView()
            document.translatesAutoresizingMaskIntoConstraints = false
            document.addSubview(hotspotCard)
            scroll.documentView = document
            let content = NSView()
            content.addSubview(scroll)
            panel.contentView = content
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: content.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
                hotspotCard.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 16),
                hotspotCard.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16),
                hotspotCard.topAnchor.constraint(equalTo: document.topAnchor, constant: 16),
                hotspotCard.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16)
            ])
            hotspotWindow = panel
        }
        reloadText()
        hotspotWindow?.center()
        hotspotWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildHotspotCard() -> NSView {
        hotspotSSIDField.stringValue = Preferences.hotspotSSID
        hotspotSSIDField.delegate = self
        hotspotToggle.onToggle = { [weak self] enabled in
            guard let self else { return }
            self.onHotspotConfigurationChange(enabled, self.hotspotSSIDField.stringValue)
            self.updateValues()
        }
        for button in [hotspotSaveButton, hotspotForgetButton, hotspotLocationButton,
                       hotspotLocationSettingsButton, hotspotWiFiSettingsButton] {
            button.bezelStyle = .rounded
            button.target = self
            button.font = .systemFont(ofSize: 11)
        }
        hotspotSaveButton.action = #selector(saveHotspotPassword)
        hotspotForgetButton.action = #selector(forgetHotspotPassword)
        hotspotLocationButton.action = #selector(requestHotspotLocation)
        hotspotLocationSettingsButton.action = #selector(openHotspotLocationSettings)
        hotspotWiFiSettingsButton.action = #selector(openHotspotWiFiSettings)
        let actions = NSStackView(views: [hotspotSaveButton, hotspotForgetButton])
        actions.spacing = 8
        let locationActions = NSStackView(views: [hotspotLocationButton, hotspotLocationSettingsButton])
        locationActions.spacing = 8
        hotspotEditLabel.isHidden = true
        let stack = cardRows([
            settingRow(title: hotspotTitle, desc: hotspotDescription, accessory: hotspotToggle),
            hotspotSSIDField, hotspotPasswordField, actions, hotspotEditLabel,
            hotspotStatusLabel, locationActions, brandDivider(),
            instantHotspotDescription, hotspotWiFiSettingsButton
        ])
        return settingsCard(stack, insets: NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18))
    }

    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as? NSTextField === hotspotSSIDField else { return }
        hotspotEditLabel.isHidden = true
        onHotspotConfigurationChange(hotspotToggle.isOn, hotspotSSIDField.stringValue)
        updateHotspotCredentialButtons()
    }

    private func updateHotspotCredentialButtons() {
        let hasSSID = !hotspotSSIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        hotspotSaveButton.isEnabled = hasSSID && !hotspotEditInFlight
        hotspotForgetButton.isEnabled = hasSSID && !hotspotEditInFlight
    }

    private func finishHotspotEdit(_ succeeded: Bool, forgot: Bool, ssid: String) {
        hotspotEditInFlight = false
        updateHotspotCredentialButtons()
        guard ssid == Preferences.hotspotSSID else { return }
        let strings = HotspotStrings.current()
        hotspotEditLabel.stringValue = succeeded ? (forgot ? strings.forgotten : strings.saved) : strings.editFailed
        hotspotEditLabel.isHidden = false
    }

    @objc private func saveHotspotPassword() {
        let ssid = hotspotSSIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = hotspotPasswordField.stringValue
        hotspotPasswordField.stringValue = ""
        hotspotEditInFlight = true
        updateHotspotCredentialButtons()
        onHotspotPasswordSave(password, ssid) { [weak self] succeeded in
            self?.finishHotspotEdit(succeeded, forgot: false, ssid: ssid)
        }
    }

    @objc private func forgetHotspotPassword() {
        hotspotPasswordField.stringValue = ""
        let ssid = hotspotSSIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        hotspotEditInFlight = true
        updateHotspotCredentialButtons()
        onHotspotPasswordForget(ssid) { [weak self] succeeded in
            self?.finishHotspotEdit(succeeded, forgot: true, ssid: ssid)
        }
    }

    @objc private func requestHotspotLocation() { onHotspotLocationRequest() }
    @objc private func openHotspotLocationSettings() { HotspotReconnectController.openLocationSettings() }
    @objc private func openHotspotWiFiSettings() { HotspotReconnectController.openWiFiSettings() }

    private func buildSystemCard() -> NSView {
        keepHotspotAliveToggle.onToggle = { [weak self] enabled in
            self?.onKeepHotspotAliveChange(enabled)
            self?.updateValues()
        }
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
        let hotspotRow = settingRow(
            title: keepHotspotAliveTitle,
            desc: keepHotspotAliveDesc,
            accessory: keepHotspotAliveToggle
        )
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
        let stack = cardRows([
            hotspotRow, brandDivider(),
            externalCapsLockOffRow, brandDivider(),
            hideIndicatorRow, hideIndicatorRestartNote, brandDivider(),
            openAtLoginRow
        ])
        stack.setCustomSpacing(6, after: hideIndicatorRow)
        return settingsCard(stack, insets: NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18))
    }

    private func buildShortcutCard() -> NSView {
        shortcutRecorder.onShortcutChange = onKeyboardShortcutChange
        shortcutRecorder.onRecordingChange = onKeyboardShortcutRecordingChange
        shortcutDesc.setContentHuggingPriority(.required, for: .vertical)

        let stack = cardRows([shortcutDesc, shortcutRecorder])
        return settingsCard(stack, insets: NSEdgeInsets(top: 17, left: 18, bottom: 18, right: 18))
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
        let versionDetails = cardRows([updateVersionRow, updateCurrentVersionLabel], spacing: 3)
        versionDetails.setHuggingPriority(.defaultLow, for: .horizontal)
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
        return settingsCard(updateCardStack, insets: NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
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

        return settingsCard(autoOffControl, insets: NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
    }

    private func updateValues() {
        dedicatedCapsLockModeToggle.setOn(Preferences.dedicatedCapsLockMode)
        menuBarToggle.setOn(Preferences.showMenuBarIcon)
        languagePopUp.setSelected(Preferences.language.rawValue)
        keepDisplayAwakeToggle.setOn(Preferences.keepDisplayAwake)
        keepHotspotAliveToggle.setOn(Preferences.keepHotspotAlive)
        hotspotToggle.setOn(Preferences.autoConnectHotspot)
        let editingSSID = hotspotSSIDField.currentEditor().map { hotspotWindow?.firstResponder === $0 } ?? false
        if !editingSSID {
            hotspotSSIDField.stringValue = Preferences.hotspotSSID
        }
        updateHotspotCredentialButtons()
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

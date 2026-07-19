import AppKit

enum SettingsPage {
    case initialPreferences
    case settings
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let settingsContentWidth: CGFloat = 420

    private let headerIcon = NSImageView()
    private let titleLabel = brandLabel(size: 20, weight: .bold, color: Brand.text)

    private let explainerCard = brandCard()
    private let explainerOnTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOnDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let explainerOffTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOffDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)

    private let preferencesHeading = brandLabel(size: 12, weight: .semibold, color: Brand.textFaint)

    private let dedicatedCapsLockModeTitle = brandLabel(size: 13, weight: .regular, color: Brand.text)
    private let dedicatedCapsLockModeDesc = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let dedicatedCapsLockModeToggle = LEDToggle(isOn: Preferences.dedicatedCapsLockMode)

    private let menuBarTitle = brandLabel(size: 13, weight: .regular, color: Brand.text)
    private let menuBarDesc = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let menuBarToggle = LEDToggle(isOn: Preferences.showMenuBarIcon)

    private let openAtLoginTitle = brandLabel(size: 13, weight: .regular, color: Brand.text)
    private let openAtLoginDesc = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let openAtLoginToggle = LEDToggle(isOn: Preferences.launchAtLogin)

    private let displaySleepOnLidCloseTitle = brandLabel(size: 13, weight: .regular, color: Brand.text)
    private let displaySleepOnLidCloseDesc = brandLabel(size: 11, color: Brand.textDim, wraps: true)
    private let displaySleepOnLidCloseToggle = LEDToggle(isOn: Preferences.displaySleepOnLidClose)

    private let languageTitle = brandLabel(size: 13, weight: .regular, color: Brand.text)
    private let languagePopUp = LanguagePopUpButton(
        items: AppLanguage.allCases.map { (title: $0.displayName, value: $0.rawValue) },
        selected: Preferences.language.rawValue
    )

    private let noteLabel = brandLabel(size: 11, color: Brand.textFaint, wraps: true)
    private let doneButton = LEDButton()

    private let rootStack = NSStackView()
    private let bodyStack = NSStackView()
    private var preferencesCard = NSView()
    private var settingsOnlyPreferenceViews: [NSView] = []
    private var initialPreferencesLayoutConstraints: [NSLayoutConstraint] = []
    private var settingsLayoutConstraints: [NSLayoutConstraint] = []

    private let onDedicatedCapsLockModeChange: (Bool) -> Void
    private let onShowMenuBarIconChange: (Bool) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onDisplaySleepOnLidCloseChange: (Bool) -> Void
    private let onFinishInitialSetup: () -> Void
    private var page: SettingsPage = .settings

    init(
        onDedicatedCapsLockModeChange: @escaping (Bool) -> Void,
        onShowMenuBarIconChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping (AppLanguage) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onDisplaySleepOnLidCloseChange: @escaping (Bool) -> Void,
        onFinishInitialSetup: @escaping () -> Void
    ) {
        self.onDedicatedCapsLockModeChange = onDedicatedCapsLockModeChange
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLanguageChange = onLanguageChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onDisplaySleepOnLidCloseChange = onDisplaySleepOnLidCloseChange
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
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
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

        let isInitialSetup = page != .settings
        window?.title = isInitialSetup ? strings.welcomeTitle : strings.settingsTitle
        titleLabel.stringValue = isInitialSetup ? strings.welcomeTitle : "Capsomnia"

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
        displaySleepOnLidCloseTitle.stringValue = strings.displaySleepOnLidClose
        displaySleepOnLidCloseDesc.stringValue = strings.displaySleepOnLidCloseDesc
        openAtLoginTitle.stringValue = strings.openAtLogin
        openAtLoginDesc.stringValue = strings.openAtLoginDesc
        languageTitle.stringValue = "Language"
        languagePopUp.setAccessibilityLabel(strings.language)

        noteLabel.stringValue = strings.initialSettingsNote
        doneButton.title = isInitialSetup ? strings.getStarted : strings.done

        explainerCard.isHidden = page != .initialPreferences
        noteLabel.isHidden = page != .initialPreferences
        for view in settingsOnlyPreferenceViews {
            view.isHidden = isInitialSetup
        }

        updateValues()
    }

    func show(page: SettingsPage) {
        self.page = page
        applyLayout()
        reloadText()
        resizeToFit()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard page == .initialPreferences else { return }
        finishInitialSetup()
    }

    private func resizeToFit() {
        guard let window, let contentView = window.contentView else { return }
        let width = Self.settingsContentWidth
        let currentHeight = max(contentView.bounds.height, 1)
        window.setContentSize(NSSize(width: width, height: currentHeight))
        contentView.layoutSubtreeIfNeeded()
        let height = contentView.fittingSize.height
        window.setContentSize(NSSize(width: width, height: height))
    }

    private func buildContent() {
        let effectView = NSVisualEffectView()
        effectView.material = .contentBackground
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.appearance = NSAppearance(named: .darkAqua)
        effectView.wantsLayer = true
        effectView.layer?.backgroundColor = Brand.bg.cgColor

        headerIcon.image = BrandIcon.make(diameter: 64)
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.alignment = .center

        let header = NSStackView(views: [headerIcon, titleLabel])
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = 8
        header.setCustomSpacing(10, after: headerIcon)

        buildExplainerCard()

        preferencesCard = buildPreferencesCard()

        doneButton.onClick = { [weak self] in self?.done() }

        configureColumn(rootStack)
        configureColumn(bodyStack)
        bodyStack.distribution = .fill
        rootStack.addArrangedSubview(header)
        rootStack.addArrangedSubview(bodyStack)
        rootStack.setCustomSpacing(20, after: header)

        effectView.addSubview(rootStack)
        window?.contentView = effectView

        initialPreferencesLayoutConstraints = [
            explainerCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            noteLabel.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]
        settingsLayoutConstraints = [
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]

        let inset = Brand.windowContentInset
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: inset),
            rootStack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -inset),
            rootStack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 36),
            rootStack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -20),
            header.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            bodyStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])

        applyLayout()
        reloadText()
    }

    private func applyLayout() {
        NSLayoutConstraint.deactivate(
            initialPreferencesLayoutConstraints + settingsLayoutConstraints
        )
        clearArrangedSubviews(bodyStack)

        let isInitialSetup = page == .initialPreferences
        if isInitialSetup {
            bodyStack.addArrangedSubview(explainerCard)
        }
        bodyStack.addArrangedSubview(preferencesHeading)
        bodyStack.addArrangedSubview(preferencesCard)
        if isInitialSetup {
            bodyStack.addArrangedSubview(noteLabel)
        }
        bodyStack.addArrangedSubview(doneButton)
        bodyStack.setCustomSpacing(8, after: preferencesHeading)
        NSLayoutConstraint.activate(
            isInitialSetup ? initialPreferencesLayoutConstraints : settingsLayoutConstraints
        )
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
        let divider = brandDivider(leadingInset: 34)

        let inner = NSStackView(views: [onRow, divider, offRow])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.translatesAutoresizingMaskIntoConstraints = false

        explainerCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: explainerCard.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: explainerCard.trailingAnchor),
            inner.topAnchor.constraint(equalTo: explainerCard.topAnchor, constant: 4),
            inner.bottomAnchor.constraint(equalTo: explainerCard.bottomAnchor, constant: -4),
            onRow.widthAnchor.constraint(equalTo: inner.widthAnchor),
            offRow.widthAnchor.constraint(equalTo: inner.widthAnchor),
            divider.widthAnchor.constraint(equalTo: inner.widthAnchor)
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
        openAtLoginToggle.onToggle = { [weak self] enabled in
            self?.onLaunchAtLoginChange(enabled)
            self?.updateValues()
        }
        displaySleepOnLidCloseToggle.onToggle = { [weak self] enabled in
            self?.onDisplaySleepOnLidCloseChange(enabled)
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
        let displaySleepOnLidCloseRow = settingRow(
            title: displaySleepOnLidCloseTitle,
            desc: displaySleepOnLidCloseDesc,
            accessory: displaySleepOnLidCloseToggle
        )
        let openAtLoginRow = settingRow(title: openAtLoginTitle, desc: openAtLoginDesc, accessory: openAtLoginToggle)
        let languageRow = settingRow(title: languageTitle, desc: nil, accessory: languagePopUp)

        let divider1 = brandDivider()
        let divider2 = brandDivider()
        let divider3 = brandDivider()
        let divider4 = brandDivider()
        settingsOnlyPreferenceViews = [
            displaySleepOnLidCloseRow,
            divider2,
            openAtLoginRow,
            divider3
        ]

        let inner = NSStackView(views: [
            menuBarRow,
            divider1,
            displaySleepOnLidCloseRow,
            divider2,
            openAtLoginRow,
            divider3,
            dedicatedCapsLockModeRow,
            divider4,
            languageRow
        ])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 0
        inner.detachesHiddenViews = true
        inner.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 2),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -2)
        ])
        for row in [
            menuBarRow,
            divider1,
            displaySleepOnLidCloseRow,
            divider2,
            openAtLoginRow,
            divider3,
            dedicatedCapsLockModeRow,
            divider4,
            languageRow
        ] {
            row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }
        return card
    }

    /// System Settings–style row: title + optional caption, accessory trailing.
    private func settingRow(title: NSTextField, desc: NSTextField?, accessory: NSView) -> NSView {
        let texts: NSView
        if let desc {
            let column = NSStackView(views: [title, desc])
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 1
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
        row.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 14)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return row
    }

    private func explainerRow(dot: NSView, title: NSTextField, desc: NSTextField) -> NSView {
        let column = NSStackView(views: [title, desc])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 1
        column.translatesAutoresizingMaskIntoConstraints = false

        let dotHolder = NSView()
        dotHolder.translatesAutoresizingMaskIntoConstraints = false
        dotHolder.addSubview(dot)
        NSLayoutConstraint.activate([
            dotHolder.widthAnchor.constraint(equalToConstant: 10),
            dot.topAnchor.constraint(equalTo: dotHolder.topAnchor, constant: 4),
            dot.leadingAnchor.constraint(equalTo: dotHolder.leadingAnchor),
            dot.bottomAnchor.constraint(lessThanOrEqualTo: dotHolder.bottomAnchor)
        ])

        let content = NSStackView(views: [dotHolder, column])
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        content.translatesAutoresizingMaskIntoConstraints = false
        return content
    }

    private func updateValues() {
        dedicatedCapsLockModeToggle.setOn(Preferences.dedicatedCapsLockMode)
        menuBarToggle.setOn(Preferences.showMenuBarIcon)
        displaySleepOnLidCloseToggle.setOn(Preferences.displaySleepOnLidClose)
        openAtLoginToggle.setOn(Preferences.launchAtLogin)
        languagePopUp.setSelected(Preferences.language.rawValue)
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

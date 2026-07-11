import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let settingsContentWidth: CGFloat = 400
    private static let initialContentWidth: CGFloat = 760

    private let headerIcon = NSImageView()
    private let titleLabel = brandLabel(size: 21, weight: .bold, color: Brand.text)

    private let explainerCard = brandCard()
    private let explainerOnTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOnDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let explainerOffTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let explainerOffDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)

    private let permissionsHeading = brandLabel(size: 11, weight: .semibold, color: Brand.textFaint)
    private let permissionsCard = brandCard()
    private let inputMonitoringTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let inputMonitoringDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let openInputMonitoringButton = OutlineButton()
    private let backgroundItemTitle = brandLabel(size: 13, weight: .semibold, color: Brand.text)
    private let backgroundItemDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)

    private let preferencesHeading = brandLabel(size: 11, weight: .semibold, color: Brand.textFaint)

    private let menuBarTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let menuBarDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let menuBarToggle = LEDToggle(isOn: Preferences.showMenuBarIcon)

    private let openAtLoginTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let openAtLoginDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let openAtLoginToggle = LEDToggle(isOn: Preferences.launchAtLogin)
    private var openAtLoginRow = NSView()
    private var openAtLoginDivider = brandDivider()

    private let displaySleepOnLidCloseTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let displaySleepOnLidCloseDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let displaySleepOnLidCloseToggle = LEDToggle(isOn: Preferences.displaySleepOnLidClose)
    private var displaySleepOnLidCloseRow = NSView()
    private var displaySleepOnLidCloseDivider = brandDivider()

    private let languageTitle = brandLabel(size: 13, weight: .medium, color: Brand.text)
    private let languageSegment = SegmentedPill(
        items: AppLanguage.allCases.map { (title: $0.displayName, value: $0.rawValue) },
        selected: Preferences.language.rawValue
    )

    private let noteLabel = brandLabel(size: 12, color: Brand.textFaint, wraps: true)
    private let doneButton = LEDButton()

    private let rootStack = NSStackView()
    private let bodyStack = NSStackView()
    private let leftColumn = NSStackView()
    private let rightColumn = NSStackView()
    private var preferencesCard = NSView()
    private var initialLayoutConstraints: [NSLayoutConstraint] = []
    private var settingsLayoutConstraints: [NSLayoutConstraint] = []

    private let onShowMenuBarIconChange: (Bool) -> Void
    private let onLanguageChange: (AppLanguage) -> Void
    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onDisplaySleepOnLidCloseChange: (Bool) -> Void
    private let onOpenInputMonitoring: () -> Void
    private let onFinishInitialSetup: () -> Void
    private var isInitialSetup = false

    init(
        onShowMenuBarIconChange: @escaping (Bool) -> Void,
        onLanguageChange: @escaping (AppLanguage) -> Void,
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onDisplaySleepOnLidCloseChange: @escaping (Bool) -> Void,
        onOpenInputMonitoring: @escaping () -> Void,
        onFinishInitialSetup: @escaping () -> Void
    ) {
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
        self.onLanguageChange = onLanguageChange
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onDisplaySleepOnLidCloseChange = onDisplaySleepOnLidCloseChange
        self.onOpenInputMonitoring = onOpenInputMonitoring
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

        permissionsHeading.stringValue = strings.permissionsHeading.uppercased()
        inputMonitoringTitle.stringValue = strings.inputMonitoringTitle
        inputMonitoringDesc.stringValue = strings.inputMonitoringDesc
        openInputMonitoringButton.title = strings.openInputMonitoring
        backgroundItemTitle.stringValue = strings.backgroundItemTitle
        backgroundItemDesc.stringValue = strings.backgroundItemDesc

        preferencesHeading.stringValue = strings.preferencesHeading.uppercased()

        menuBarTitle.stringValue = strings.showMenuBarIcon
        menuBarDesc.stringValue = strings.showMenuBarIconDesc
        displaySleepOnLidCloseTitle.stringValue = strings.displaySleepOnLidClose
        displaySleepOnLidCloseDesc.stringValue = strings.displaySleepOnLidCloseDesc
        openAtLoginTitle.stringValue = strings.openAtLogin
        openAtLoginDesc.stringValue = strings.openAtLoginDesc
        languageTitle.stringValue = strings.language

        noteLabel.stringValue = strings.initialSettingsNote
        doneButton.title = isInitialSetup ? strings.getStarted : strings.done

        explainerCard.isHidden = !isInitialSetup
        permissionsHeading.isHidden = !isInitialSetup
        permissionsCard.isHidden = !isInitialSetup
        displaySleepOnLidCloseRow.isHidden = isInitialSetup
        displaySleepOnLidCloseDivider.isHidden = isInitialSetup
        openAtLoginRow.isHidden = isInitialSetup
        openAtLoginDivider.isHidden = isInitialSetup
        noteLabel.isHidden = !isInitialSetup

        updateValues()
    }

    func show(initialSetup: Bool) {
        isInitialSetup = initialSetup
        applyLayout()
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
        guard let window, let contentView = window.contentView else { return }
        let width = isInitialSetup ? Self.initialContentWidth : Self.settingsContentWidth
        let currentHeight = max(contentView.bounds.height, 1)
        window.setContentSize(NSSize(width: width, height: currentHeight))
        contentView.layoutSubtreeIfNeeded()
        let height = contentView.fittingSize.height
        window.setContentSize(NSSize(width: width, height: height))
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
        buildPermissionsCard()

        preferencesCard = buildPreferencesCard()

        doneButton.onClick = { [weak self] in self?.done() }
        openInputMonitoringButton.onClick = { [weak self] in self?.onOpenInputMonitoring() }

        configureColumn(rootStack)
        configureColumn(leftColumn)
        configureColumn(rightColumn)
        rootStack.addArrangedSubview(header)
        rootStack.addArrangedSubview(bodyStack)
        rootStack.setCustomSpacing(20, after: header)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rootStack)
        window?.contentView = contentView

        initialLayoutConstraints = [
            explainerCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor),
            permissionsCard.widthAnchor.constraint(equalTo: leftColumn.widthAnchor),
            preferencesCard.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
            noteLabel.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: rightColumn.widthAnchor)
        ]
        settingsLayoutConstraints = [
            preferencesCard.widthAnchor.constraint(equalTo: bodyStack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: bodyStack.widthAnchor)
        ]

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            header.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            bodyStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])

        applyLayout()
        reloadText()
    }

    private func applyLayout() {
        NSLayoutConstraint.deactivate(initialLayoutConstraints + settingsLayoutConstraints)
        clearArrangedSubviews(bodyStack)
        clearArrangedSubviews(leftColumn)
        clearArrangedSubviews(rightColumn)

        if isInitialSetup {
            leftColumn.addArrangedSubview(explainerCard)
            leftColumn.addArrangedSubview(permissionsHeading)
            leftColumn.addArrangedSubview(permissionsCard)
            leftColumn.setCustomSpacing(8, after: permissionsHeading)

            rightColumn.addArrangedSubview(preferencesHeading)
            rightColumn.addArrangedSubview(preferencesCard)
            rightColumn.addArrangedSubview(noteLabel)
            rightColumn.addArrangedSubview(doneButton)
            rightColumn.setCustomSpacing(8, after: preferencesHeading)

            bodyStack.orientation = .horizontal
            bodyStack.alignment = .top
            bodyStack.distribution = .fillEqually
            bodyStack.spacing = 16
            bodyStack.addArrangedSubview(leftColumn)
            bodyStack.addArrangedSubview(rightColumn)
            NSLayoutConstraint.activate(initialLayoutConstraints)
        } else {
            bodyStack.orientation = .vertical
            bodyStack.alignment = .leading
            bodyStack.distribution = .fill
            bodyStack.spacing = 16
            bodyStack.addArrangedSubview(preferencesHeading)
            bodyStack.addArrangedSubview(preferencesCard)
            bodyStack.addArrangedSubview(doneButton)
            bodyStack.setCustomSpacing(8, after: preferencesHeading)
            NSLayoutConstraint.activate(settingsLayoutConstraints)
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

    private func buildPermissionsCard() {
        let inputRow = explainerRow(
            dot: brandStatusDot(on: true),
            title: inputMonitoringTitle,
            desc: inputMonitoringDesc
        )
        let backgroundRow = explainerRow(
            dot: brandStatusDot(on: false),
            title: backgroundItemTitle,
            desc: backgroundItemDesc
        )

        let inner = NSStackView(views: [inputRow, openInputMonitoringButton, backgroundRow])
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 14
        inner.translatesAutoresizingMaskIntoConstraints = false

        permissionsCard.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: permissionsCard.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: permissionsCard.trailingAnchor, constant: -16),
            inner.topAnchor.constraint(equalTo: permissionsCard.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: permissionsCard.bottomAnchor, constant: -16),
            inputRow.widthAnchor.constraint(equalTo: inner.widthAnchor),
            openInputMonitoringButton.widthAnchor.constraint(equalTo: inner.widthAnchor),
            backgroundRow.widthAnchor.constraint(equalTo: inner.widthAnchor)
        ])
    }

    private func buildPreferencesCard() -> NSView {
        let card = brandCard()

        menuBarToggle.onToggle = { [weak self] enabled in self?.onShowMenuBarIconChange(enabled) }
        openAtLoginToggle.onToggle = { [weak self] enabled in
            self?.onLaunchAtLoginChange(enabled)
            self?.updateValues()
        }
        displaySleepOnLidCloseToggle.onToggle = { [weak self] enabled in
            self?.onDisplaySleepOnLidCloseChange(enabled)
            self?.updateValues()
        }
        languageSegment.onSelect = { [weak self] rawValue in
            guard let language = AppLanguage(rawValue: rawValue) else { return }
            self?.onLanguageChange(language)
        }

        let menuBarRow = settingRow(title: menuBarTitle, desc: menuBarDesc, accessory: menuBarToggle)
        displaySleepOnLidCloseRow = settingRow(
            title: displaySleepOnLidCloseTitle,
            desc: displaySleepOnLidCloseDesc,
            accessory: displaySleepOnLidCloseToggle
        )
        openAtLoginRow = settingRow(title: openAtLoginTitle, desc: openAtLoginDesc, accessory: openAtLoginToggle)
        let languageRow = settingRow(title: languageTitle, desc: nil, accessory: languageSegment)

        let divider1 = displaySleepOnLidCloseDivider
        let divider2 = openAtLoginDivider
        let divider3 = brandDivider()

        let inner = NSStackView(views: [
            menuBarRow,
            divider1,
            displaySleepOnLidCloseRow,
            divider2,
            openAtLoginRow,
            divider3,
            languageRow
        ])
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
        for row in [menuBarRow, divider1, displaySleepOnLidCloseRow, divider2, openAtLoginRow, divider3, languageRow] {
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
        displaySleepOnLidCloseToggle.setOn(Preferences.displaySleepOnLidClose)
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

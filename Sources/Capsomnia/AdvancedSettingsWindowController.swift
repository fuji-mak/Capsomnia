import AppKit

final class AdvancedSettingsWindowController: NSWindowController {
    private static let contentWidth: CGFloat = 420

    private let titleLabel = brandLabel(size: 18, weight: .bold, color: Brand.text)
    private let subtitleLabel = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let systemBehaviorHeading = brandLabel(
        size: 11,
        weight: .semibold,
        color: Brand.textFaint
    )
    private let shortcutHeading = brandLabel(
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

    private let shortcutDesc = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let shortcutPreviewNote = brandLabel(
        size: 11,
        color: Brand.textFaint,
        wraps: true
    )
    private let shortcutRecorder = ShortcutRecorderButton(
        placeholder: "",
        recording: ""
    )
    private let doneButton = LEDButton()

    private let onLaunchAtLoginChange: (Bool) -> Void
    private let onDisplaySleepOnLidCloseChange: (Bool) -> Void

    init(
        onLaunchAtLoginChange: @escaping (Bool) -> Void,
        onDisplaySleepOnLidCloseChange: @escaping (Bool) -> Void
    ) {
        self.onLaunchAtLoginChange = onLaunchAtLoginChange
        self.onDisplaySleepOnLidCloseChange = onDisplaySleepOnLidCloseChange

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.contentWidth,
                height: 460
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = Brand.bg
        window.appearance = NSAppearance(named: .darkAqua)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true

        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func reloadText() {
        let strings = AppStrings.current()

        window?.title = strings.advancedSettingsTitle
        titleLabel.stringValue = strings.advancedSettingsTitle
        subtitleLabel.stringValue = strings.advancedSettingsSubtitle
        systemBehaviorHeading.stringValue = strings.systemBehavior.uppercased()
        shortcutHeading.stringValue = strings.keyboardShortcut.uppercased()

        displaySleepOnLidCloseTitle.stringValue = strings.displaySleepOnLidClose
        displaySleepOnLidCloseDesc.stringValue = strings.displaySleepOnLidCloseDesc
        displaySleepOnLidCloseToggle.setAccessibilityLabel(strings.displaySleepOnLidClose)

        openAtLoginTitle.stringValue = strings.openAtLogin
        openAtLoginDesc.stringValue = strings.openAtLoginDesc
        openAtLoginToggle.setAccessibilityLabel(strings.openAtLogin)

        shortcutDesc.stringValue = strings.keyboardShortcutDesc
        shortcutPreviewNote.stringValue = strings.shortcutPreviewNote
        shortcutRecorder.setStrings(
            placeholder: strings.shortcutRecorderPlaceholder,
            recording: strings.shortcutRecorderRecording
        )
        shortcutRecorder.setAccessibilityLabel(strings.keyboardShortcut)
        shortcutRecorder.setAccessibilityHelp(strings.shortcutPreviewNote)

        doneButton.title = strings.done
        updateValues()
    }

    func show(relativeTo parentWindow: NSWindow) {
        reloadText()
        resizeToFit()

        if window?.sheetParent !== parentWindow, let window {
            parentWindow.beginSheet(window)
        }
    }

    private func buildContent() {
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Brand.bg.cgColor

        let header = buildHeader()
        let systemCard = buildSystemCard()
        let shortcutCard = buildShortcutCard()

        let stack = NSStackView(views: [
            header,
            systemBehaviorHeading,
            systemCard,
            shortcutHeading,
            shortcutCard,
            doneButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(22, after: header)
        stack.setCustomSpacing(8, after: systemBehaviorHeading)
        stack.setCustomSpacing(18, after: systemCard)
        stack.setCustomSpacing(8, after: shortcutHeading)
        stack.setCustomSpacing(20, after: shortcutCard)

        doneButton.onClick = { [weak self] in
            self?.dismiss()
        }

        contentView.addSubview(stack)
        window?.contentView = contentView

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            systemBehaviorHeading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            systemCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutHeading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            doneButton.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        reloadText()
    }

    private func buildHeader() -> NSView {
        let iconHolder = NSView()
        iconHolder.wantsLayer = true
        iconHolder.layer?.backgroundColor = Brand.surface2.cgColor
        iconHolder.layer?.cornerRadius = 12
        iconHolder.layer?.borderWidth = 1
        iconHolder.layer?.borderColor = Brand.borderStrong.cgColor
        iconHolder.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: "slider.horizontal.3",
            accessibilityDescription: nil
        )
        icon.contentTintColor = Brand.led
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 17,
            weight: .medium
        )
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconHolder.addSubview(icon)

        let labels = NSStackView(views: [titleLabel, subtitleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [iconHolder, labels])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconHolder.widthAnchor.constraint(equalToConstant: 42),
            iconHolder.heightAnchor.constraint(equalToConstant: 42),
            icon.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor)
        ])
        return header
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
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            displayRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            openAtLoginRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return card
    }

    private func buildShortcutCard() -> NSView {
        let card = brandCard()
        let stack = NSStackView(views: [
            shortcutDesc,
            shortcutRecorder,
            shortcutPreviewNote
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(8, after: shortcutRecorder)

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            shortcutDesc.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutRecorder.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutPreviewNote.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return card
    }

    private func settingRow(
        title: NSTextField,
        desc: NSTextField,
        accessory: NSView
    ) -> NSView {
        let labels = NSStackView(views: [title, desc])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)

        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = NSStackView(views: [labels, accessory])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func updateValues() {
        displaySleepOnLidCloseToggle.setOn(Preferences.displaySleepOnLidClose)
        openAtLoginToggle.setOn(Preferences.launchAtLogin)
    }

    private func resizeToFit() {
        guard let window, let contentView = window.contentView else { return }
        window.setContentSize(NSSize(width: Self.contentWidth, height: 460))
        contentView.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(
            width: Self.contentWidth,
            height: contentView.fittingSize.height
        ))
    }

    private func dismiss() {
        guard let window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
    }
}

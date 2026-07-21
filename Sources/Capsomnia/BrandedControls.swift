import AppKit

// MARK: - Branded controls

/// On/off pill toggle drawn in the landing-page LED palette.
final class LEDToggle: NSView {
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

        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
        setAccessibilityEnabled(true)
        focusRingType = .exterior
        apply(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool {
        true
    }

    func setOn(_ value: Bool) {
        isOn = value
        apply(animated: false)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        toggle()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
            toggle()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        toggle()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func drawFocusRingMask() {
        NSBezierPath(
            roundedRect: bounds,
            xRadius: bounds.height / 2,
            yRadius: bounds.height / 2
        ).fill()
    }

    override var focusRingMaskBounds: NSRect {
        bounds
    }

    private func toggle() {
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
        setAccessibilityValue(isOn ? 1 : 0)
    }
}

/// A compact, native pop-up button for choosing one language.
final class LanguagePopUpButton: NSPopUpButton {
    var onSelect: ((String) -> Void)?

    init(items: [(title: String, value: String)], selected: String) {
        super.init(frame: .zero, pullsDown: false)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        controlSize = .small
        font = .systemFont(ofSize: 12, weight: .semibold)
        alignment = .left
        bezelStyle = .rounded
        bezelColor = Brand.surface2
        contentTintColor = Brand.text
        target = self
        action = #selector(selectionChanged)

        menu?.removeAllItems()
        for item in items {
            let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
            menuItem.representedObject = item.value
            menu?.addItem(menuItem)
        }
        setSelected(selected)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 124),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { nil }

    var selectedValue: String {
        selectedItem?.representedObject as? String ?? ""
    }

    func setSelected(_ value: String) {
        guard let item = itemArray.first(where: { $0.representedObject as? String == value }) else {
            selectItem(at: 0)
            return
        }
        select(item)
    }

    @objc private func selectionChanged() {
        onSelect?(selectedValue)
    }
}

/// A full-width navigation card used to reveal a deeper settings page.
final class DisclosureButton: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let chevronHolder = NSView()
    private let chevronView = NSImageView()
    private var isHovered = false

    var onClick: (() -> Void)?

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        focusRingType = .exterior

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityEnabled(true)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = Brand.text
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        subtitleLabel.textColor = Brand.textDim
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let labels = NSStackView(views: [titleLabel, subtitleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chevronHolder.translatesAutoresizingMaskIntoConstraints = false
        chevronHolder.wantsLayer = true
        chevronHolder.layer?.cornerRadius = 9

        chevronView.image = NSImage(
            systemSymbolName: "chevron.forward",
            accessibilityDescription: nil
        )
        chevronView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 11,
            weight: .semibold
        )
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronHolder.addSubview(chevronView)

        let content = NSStackView(views: [labels, chevronHolder])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.distribution = .fill
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 62),
            chevronHolder.widthAnchor.constraint(equalToConstant: 30),
            chevronHolder.heightAnchor.constraint(equalToConstant: 30),
            chevronView.centerXAnchor.constraint(equalTo: chevronHolder.centerXAnchor),
            chevronView.centerYAnchor.constraint(equalTo: chevronHolder.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            content.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        ))
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool {
        true
    }

    func setStrings(title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        setAccessibilityLabel(title)
        setAccessibilityHelp(subtitle)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshAppearance()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
            onClick?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func drawFocusRingMask() {
        NSBezierPath(
            roundedRect: bounds,
            xRadius: 12,
            yRadius: 12
        ).fill()
    }

    override var focusRingMaskBounds: NSRect {
        bounds
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func refreshAppearance() {
        layer?.backgroundColor = (isHovered ? Brand.surface2 : Brand.surface).cgColor
        layer?.borderColor = (
            isHovered ? Brand.led.withAlphaComponent(0.38) : Brand.border
        ).cgColor
        chevronHolder.layer?.backgroundColor = (
            isHovered ? Brand.led.withAlphaComponent(0.13) : Brand.surface2
        ).cgColor
        chevronView.contentTintColor = isHovered ? Brand.led : Brand.textDim
    }
}

/// A keycap-style recorder for Capsomnia's persisted global shortcut.
final class ShortcutRecorderButton: NSView {
    private var placeholderTitle: String
    private var recordingTitle: String
    private var actionTitle: String
    private var registrationFailedTitle: String
    private var shortcut: KeyboardShortcut?
    private var isRecording = false
    private var isHovered = false
    private var isShowingRegistrationError = false
    private var renderedKeycapTokens: [String] = []

    var onShortcutChange: ((KeyboardShortcut?) -> Bool)?
    var onRecordingChange: ((Bool) -> Void)?

    private let iconHolder = NSView()
    private let iconView = NSImageView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let flexibleSpace = NSView()
    private let keycapStack = NSStackView()
    private let actionPill = NSView()
    private let actionLabel = NSTextField(labelWithString: "")

    init(
        placeholder: String,
        recording: String,
        action: String,
        registrationFailed: String
    ) {
        placeholderTitle = placeholder
        recordingTitle = recording
        actionTitle = action
        registrationFailedTitle = registrationFailed
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = Brand.surface2.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Brand.borderStrong.cgColor
        focusRingType = .exterior

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityEnabled(true)

        iconHolder.translatesAutoresizingMaskIntoConstraints = false
        iconHolder.wantsLayer = true
        iconHolder.layer?.cornerRadius = 10
        iconHolder.layer?.backgroundColor = Brand.led.withAlphaComponent(0.09).cgColor
        iconHolder.layer?.borderWidth = 1
        iconHolder.layer?.borderColor = Brand.led.withAlphaComponent(0.2).cgColor

        iconView.image = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: nil
        )
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 16,
            weight: .medium
        )
        iconView.contentTintColor = Brand.led
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconHolder.addSubview(iconView)

        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = Brand.textDim
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        flexibleSpace.translatesAutoresizingMaskIntoConstraints = false
        flexibleSpace.setContentHuggingPriority(
            NSLayoutConstraint.Priority(rawValue: 1),
            for: .horizontal
        )

        keycapStack.orientation = .horizontal
        keycapStack.alignment = .centerY
        keycapStack.spacing = 7
        keycapStack.translatesAutoresizingMaskIntoConstraints = false
        keycapStack.setContentHuggingPriority(.required, for: .horizontal)

        actionPill.translatesAutoresizingMaskIntoConstraints = false
        actionPill.wantsLayer = true
        actionPill.layer?.cornerRadius = 8
        actionPill.layer?.backgroundColor = Brand.led.withAlphaComponent(0.1).cgColor
        actionPill.layer?.borderWidth = 1
        actionPill.layer?.borderColor = Brand.led.withAlphaComponent(0.28).cgColor

        actionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        actionLabel.textColor = Brand.led
        actionLabel.alignment = .center
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionPill.addSubview(actionLabel)

        let content = NSStackView(views: [
            iconHolder,
            valueLabel,
            flexibleSpace,
            keycapStack,
            actionPill
        ])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 12
        content.detachesHiddenViews = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 68),
            iconHolder.widthAnchor.constraint(equalToConstant: 40),
            iconHolder.heightAnchor.constraint(equalToConstant: 40),
            iconView.centerXAnchor.constraint(equalTo: iconHolder.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconHolder.centerYAnchor),
            actionLabel.leadingAnchor.constraint(equalTo: actionPill.leadingAnchor, constant: 11),
            actionLabel.trailingAnchor.constraint(equalTo: actionPill.trailingAnchor, constant: -11),
            actionLabel.topAnchor.constraint(equalTo: actionPill.topAnchor, constant: 7),
            actionLabel.bottomAnchor.constraint(equalTo: actionPill.bottomAnchor, constant: -7),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        ))
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    var title: String {
        isRecording ? recordingTitle : shortcut?.displayValue ?? placeholderTitle
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    func setStrings(
        placeholder: String,
        recording: String,
        action: String,
        registrationFailed: String
    ) {
        placeholderTitle = placeholder
        recordingTitle = recording
        actionTitle = action
        registrationFailedTitle = registrationFailed
        refreshAppearance()
    }

    func setShortcut(_ shortcut: KeyboardShortcut?) {
        self.shortcut = shortcut
        isShowingRegistrationError = false
        refreshAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshAppearance()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func beginRecording() {
        guard !isRecording else { return }
        isShowingRegistrationError = false
        isRecording = true
        onRecordingChange?(true)
        window?.makeFirstResponder(self)
        refreshAppearance()
    }

    private func endRecording() {
        guard isRecording else { return }
        isRecording = false
        onRecordingChange?(false)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
                beginRecording()
                return
            }
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            endRecording()
            refreshAppearance()
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            commit(nil)
            return
        }

        guard let candidate = KeyboardShortcut(event: event) else {
            NSSound.beep()
            return
        }

        commit(candidate)
    }

    override func accessibilityPerformPress() -> Bool {
        beginRecording()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if isRecording {
            endRecording()
            refreshAppearance()
        }
        needsDisplay = true
        return result
    }

    override func drawFocusRingMask() {
        NSBezierPath(
            roundedRect: bounds,
            xRadius: 12,
            yRadius: 12
        ).fill()
    }

    override var focusRingMaskBounds: NSRect {
        bounds
    }

    private func commit(_ candidate: KeyboardShortcut?) {
        endRecording()
        if onShortcutChange?(candidate) ?? true {
            shortcut = candidate
            isShowingRegistrationError = false
        } else {
            isShowingRegistrationError = true
            NSSound.beep()
        }
        refreshAppearance()
    }

    private func refreshAppearance() {
        valueLabel.stringValue = isShowingRegistrationError
            ? registrationFailedTitle
            : title
        valueLabel.textColor = isShowingRegistrationError
            ? .systemRed
            : isRecording ? Brand.led : Brand.textDim
        actionLabel.stringValue = isRecording ? "Esc" : actionTitle

        let tokens = shortcut?.displayTokens ?? []
        let hasRecordedShortcut = !tokens.isEmpty
            && !isRecording
            && !isShowingRegistrationError
        valueLabel.isHidden = hasRecordedShortcut
        keycapStack.isHidden = !hasRecordedShortcut
        actionPill.isHidden = hasRecordedShortcut

        if hasRecordedShortcut, tokens != renderedKeycapTokens {
            renderedKeycapTokens = tokens
            rebuildKeycaps()
        }

        let highlighted = isRecording || isHovered
        if isShowingRegistrationError {
            layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.72).cgColor
        } else {
            layer?.borderColor = (
                highlighted
                    ? Brand.led.withAlphaComponent(isRecording ? 0.72 : 0.42)
                    : Brand.borderStrong
            ).cgColor
        }
        layer?.backgroundColor = (
            isShowingRegistrationError
                ? NSColor.systemRed.withAlphaComponent(0.055)
                : highlighted
                ? Brand.led.withAlphaComponent(isRecording ? 0.075 : 0.035)
                : Brand.surface2
        ).cgColor
        iconHolder.layer?.backgroundColor = Brand.led.withAlphaComponent(
            highlighted ? 0.15 : 0.09
        ).cgColor
        setAccessibilityValue(
            isShowingRegistrationError ? registrationFailedTitle : title
        )
    }

    private func rebuildKeycaps() {
        for view in keycapStack.arrangedSubviews {
            keycapStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for token in renderedKeycapTokens {
            keycapStack.addArrangedSubview(ShortcutKeycapView(value: token))
        }
    }
}

private final class ShortcutKeycapView: NSView {
    init(value: String) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = Brand.surface.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Brand.borderStrong.cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowRadius = 0
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(
            ofSize: value.count > 1 ? 10 : 15,
            weight: .semibold
        )
        label.textColor = Brand.text
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(
                equalToConstant: max(32, label.intrinsicContentSize.width + 17)
            ),
            heightAnchor.constraint(equalToConstant: 32),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1)
        ])
    }

    required init?(coder: NSCoder) { nil }
}

/// LED-green primary button matching the landing-page CTA.
final class LEDButton: NSView {
    private let label = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?

    var title: String {
        get { label.stringValue }
        set {
            label.stringValue = newValue
            setAccessibilityLabel(newValue)
        }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = Brand.led.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityEnabled(true)
        focusRingType = .exterior

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

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        performAction()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
            performAction()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        performAction()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func drawFocusRingMask() {
        NSBezierPath(
            roundedRect: bounds,
            xRadius: 11,
            yRadius: 11
        ).fill()
    }

    override var focusRingMaskBounds: NSRect {
        bounds
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

    private func performAction() {
        onClick?()
    }
}

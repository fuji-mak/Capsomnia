import AppKit

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
    private let deletePill = NSView()
    private let deleteLabel = NSTextField(labelWithString: "Del")
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

        deletePill.translatesAutoresizingMaskIntoConstraints = false
        deletePill.wantsLayer = true
        deletePill.layer?.cornerRadius = 8
        deletePill.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
        deletePill.layer?.borderWidth = 1
        deletePill.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.28).cgColor

        deleteLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        deleteLabel.textColor = .systemRed
        deleteLabel.alignment = .center
        deleteLabel.translatesAutoresizingMaskIntoConstraints = false
        deletePill.addSubview(deleteLabel)

        let content = NSStackView(views: [
            iconHolder,
            valueLabel,
            flexibleSpace,
            keycapStack,
            deletePill,
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
            deleteLabel.leadingAnchor.constraint(equalTo: deletePill.leadingAnchor, constant: 11),
            deleteLabel.trailingAnchor.constraint(equalTo: deletePill.trailingAnchor, constant: -11),
            deleteLabel.topAnchor.constraint(equalTo: deletePill.topAnchor, constant: 7),
            deleteLabel.bottomAnchor.constraint(equalTo: deletePill.bottomAnchor, constant: -7),
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

    func cancelRecording() {
        guard isRecording else { return }
        endRecording()
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
        cancelRecording()
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
        deletePill.isHidden = !(isRecording && shortcut != nil)

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

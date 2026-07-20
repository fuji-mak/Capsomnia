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

/// A visual shortcut recorder used by the advanced-settings preview.
///
/// It records a display value for the current app session only. Registering
/// and persisting the global shortcut belongs to the shortcut feature itself.
final class ShortcutRecorderButton: NSButton {
    private var placeholderTitle: String
    private var recordingTitle: String
    private var recordedDisplay: String?
    private var isRecording = false

    init(placeholder: String, recording: String) {
        placeholderTitle = placeholder
        recordingTitle = recording
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        bezelStyle = .rounded
        controlSize = .large
        alignment = .center
        font = .systemFont(ofSize: 12, weight: .medium)
        contentTintColor = Brand.text
        bezelColor = Brand.surface2
        imagePosition = .noImage
        title = placeholder
        target = self
        action = #selector(beginRecording)
        focusRingType = .exterior

        heightAnchor.constraint(equalToConstant: 40).isActive = true
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool {
        true
    }

    func setStrings(placeholder: String, recording: String) {
        placeholderTitle = placeholder
        recordingTitle = recording
        refreshTitle()
    }

    @objc private func beginRecording() {
        isRecording = true
        refreshTitle()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            isRecording = false
            refreshTitle()
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 {
            recordedDisplay = nil
            isRecording = false
            refreshTitle()
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let relevantModifiers = modifiers.intersection([.control, .option, .shift, .command])
        guard !relevantModifiers.isEmpty,
              let characters = event.charactersIgnoringModifiers,
              let character = characters.first,
              !character.isWhitespace else {
            NSSound.beep()
            return
        }

        recordedDisplay = shortcutDisplay(
            modifiers: relevantModifiers,
            character: character
        )
        isRecording = false
        refreshTitle()
    }

    private func refreshTitle() {
        let value = isRecording
            ? recordingTitle
            : recordedDisplay ?? placeholderTitle
        attributedTitle = NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isRecording ? Brand.led : Brand.textDim
            ]
        )
        bezelColor = isRecording
            ? Brand.led.withAlphaComponent(0.24)
            : Brand.surface2
        setAccessibilityValue(value)
    }

    private func shortcutDisplay(
        modifiers: NSEvent.ModifierFlags,
        character: Character
    ) -> String {
        var value = ""
        if modifiers.contains(.control) {
            value += "⌃"
        }
        if modifiers.contains(.option) {
            value += "⌥"
        }
        if modifiers.contains(.shift) {
            value += "⇧"
        }
        if modifiers.contains(.command) {
            value += "⌘"
        }
        value += String(character).uppercased()
        return value
    }
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

/// A plain view that forwards a click as a closure.
final class ClickableView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

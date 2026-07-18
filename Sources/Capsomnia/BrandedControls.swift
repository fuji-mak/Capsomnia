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

        apply(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    func setOn(_ value: Bool) {
        isOn = value
        apply(animated: false)
    }

    override func mouseDown(with event: NSEvent) {
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

    /// Update the visible titles (e.g. after a language change) without losing selection.
    func updateTitles(_ items: [(title: String, value: String)]) {
        let selected = selectedValue
        for item in items {
            itemArray.first(where: { $0.representedObject as? String == item.value })?.title = item.title
        }
        setSelected(selected)
    }

    @objc private func selectionChanged() {
        onSelect?(selectedValue)
    }
}

/// LED-green primary button matching the landing-page CTA.
final class LEDButton: NSView {
    private let label = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?

    var title: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = Brand.led.cgColor
        translatesAutoresizingMaskIntoConstraints = false

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

    override func mouseDown(with event: NSEvent) {
        onClick?()
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

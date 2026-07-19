import AppKit

// MARK: - Branded controls (macOS 26 dark)

/// System-style switch: green track when on, white knob.
final class LEDToggle: NSView {
    private let track = CALayer()
    private let knob = CALayer()
    private let offGlyph = CAShapeLayer()
    private let onGlyph = CAShapeLayer()
    private(set) var isOn: Bool
    var onToggle: ((Bool) -> Void)?

    private let trackWidth: CGFloat = 40
    private let trackHeight: CGFloat = 24
    private let knobSize: CGFloat = 20
    private let knobInset: CGFloat = 2

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(x: 0, y: 0, width: trackWidth, height: trackHeight))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: trackWidth).isActive = true
        heightAnchor.constraint(equalToConstant: trackHeight).isActive = true

        track.frame = NSRect(x: 0, y: 0, width: trackWidth, height: trackHeight)
        track.cornerRadius = trackHeight / 2
        track.cornerCurve = .continuous
        layer?.addSublayer(track)

        offGlyph.fillColor = nil
        offGlyph.strokeColor = NSColor.black.withAlphaComponent(0.28).cgColor
        offGlyph.lineWidth = 1.25
        offGlyph.path = CGPath(
            ellipseIn: CGRect(x: trackWidth - 14.5, y: (trackHeight - 7) / 2, width: 7, height: 7),
            transform: nil
        )
        track.addSublayer(offGlyph)

        onGlyph.fillColor = NSColor.black.withAlphaComponent(0.28).cgColor
        onGlyph.path = CGPath(
            roundedRect: CGRect(x: 9, y: (trackHeight - 9) / 2, width: 2, height: 9),
            cornerWidth: 1,
            cornerHeight: 1,
            transform: nil
        )
        track.addSublayer(onGlyph)

        knob.bounds = CGRect(x: 0, y: 0, width: knobSize, height: knobSize)
        knob.cornerRadius = knobSize / 2
        knob.cornerCurve = .continuous
        knob.backgroundColor = Brand.switchKnob.cgColor
        knob.shadowColor = NSColor.black.cgColor
        knob.shadowOpacity = 0.22
        knob.shadowRadius = 2.5
        knob.shadowOffset = CGSize(width: 0, height: -0.5)
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
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        track.backgroundColor = (isOn ? Brand.switchOn : Brand.switchOff).cgColor
        let knobX = isOn ? trackWidth - knobSize - knobInset : knobInset
        knob.position = CGPoint(x: knobX + knobSize / 2, y: trackHeight / 2)
        offGlyph.opacity = isOn ? 0 : 1
        onGlyph.opacity = isOn ? 1 : 0

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
        font = .systemFont(ofSize: 12, weight: .medium)
        alignment = .left
        bezelStyle = .rounded
        appearance = NSAppearance(named: .darkAqua)
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

/// Full-width LED primary button at the bottom of the settings window.
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
        layer?.cornerCurve = .continuous
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

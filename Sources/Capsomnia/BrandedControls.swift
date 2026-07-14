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

/// Segmented control matching the landing-page EN/JA language switch.
final class SegmentedPill: NSView {
    private struct Segment {
        let value: String
        let container: ClickableView
        let label: NSTextField
    }

    private var segments: [Segment] = []
    private(set) var selectedValue: String
    var onSelect: ((String) -> Void)?

    init(items: [(title: String, value: String)], selected: String) {
        selectedValue = selected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = Brand.surface2.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Brand.borderStrong.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for item in items {
            let container = ClickableView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 8
            container.translatesAutoresizingMaskIntoConstraints = false

            let label = NSTextField(labelWithString: item.title)
            label.font = .systemFont(ofSize: 12, weight: .bold)
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: 24),
                container.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 10)
            ])

            let value = item.value
            container.onClick = { [weak self] in self?.select(value) }
            stack.addArrangedSubview(container)
            segments.append(Segment(value: value, container: container, label: label))
        }

        updateSelection()
    }

    required init?(coder: NSCoder) { nil }

    func setSelected(_ value: String) {
        selectedValue = value
        updateSelection()
    }

    private func select(_ value: String) {
        guard value != selectedValue else { return }
        selectedValue = value
        updateSelection()
        onSelect?(value)
    }

    private func updateSelection() {
        for segment in segments {
            let isSelected = segment.value == selectedValue
            segment.container.layer?.backgroundColor = isSelected ? Brand.led.cgColor : NSColor.clear.cgColor
            segment.label.textColor = isSelected ? .black : Brand.textDim
        }
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

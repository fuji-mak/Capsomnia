import AppKit

/// A full-width navigation card used to reveal a deeper settings page.
final class DisclosureButton: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
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

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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

        let content = NSStackView(views: [titleLabel, chevronHolder])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.distribution = .fill
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),
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

    func setTitle(_ title: String) {
        titleLabel.stringValue = title
        setAccessibilityLabel(title)
        setAccessibilityHelp(nil)
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

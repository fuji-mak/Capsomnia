import AppKit

// MARK: - Branded view factories

func brandLabel(
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor,
    wraps: Bool = false
) -> NSTextField {
    let label = NSTextField(labelWithString: "")
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.translatesAutoresizingMaskIntoConstraints = false
    if wraps {
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    return label
}

func brandCard() -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = Brand.surface.cgColor
    view.layer?.cornerRadius = 14
    view.layer?.borderWidth = 1
    view.layer?.borderColor = Brand.border.cgColor
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

func brandDivider() -> NSView {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = Brand.border.cgColor
    view.translatesAutoresizingMaskIntoConstraints = false
    view.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return view
}

func brandStatusDot(on: Bool) -> NSView {
    let dot = NSView()
    dot.wantsLayer = true
    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
    dot.heightAnchor.constraint(equalToConstant: 12).isActive = true
    dot.layer?.cornerRadius = 6
    if on {
        dot.layer?.backgroundColor = Brand.led.cgColor
        dot.layer?.shadowColor = Brand.led.cgColor
        dot.layer?.shadowOpacity = 0.85
        dot.layer?.shadowRadius = 5
        dot.layer?.shadowOffset = .zero
        dot.layer?.masksToBounds = false
    } else {
        dot.layer?.backgroundColor = Brand.offDot.cgColor
        dot.layer?.borderWidth = 1
        dot.layer?.borderColor = Brand.offDotBorder.cgColor
    }
    return dot
}

enum BrandIcon {
    static func make(diameter: CGFloat, color: NSColor = Brand.led, glow: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: diameter, height: diameter))
        image.lockFocus()
        let center = NSPoint(x: diameter / 2, y: diameter / 2)
        if glow, let glow = NSGradient(colors: [
            color.withAlphaComponent(0.95),
            color.withAlphaComponent(0.45),
            color.withAlphaComponent(0.0)
        ]) {
            glow.draw(fromCenter: center, radius: 0, toCenter: center, radius: diameter / 2, options: [])
        }
        color.setFill()
        let radius = diameter * 0.20
        NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

enum DotImage {
    static func make(color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

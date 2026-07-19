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

/// Grouped-list surface (macOS 26 dark Group Box).
func brandCard() -> NSView {
    let view = GlassCardView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}

/// Inset separator for System Settings–style grouped rows.
func brandDivider(leadingInset: CGFloat = 16) -> NSView {
    let holder = NSView()
    holder.translatesAutoresizingMaskIntoConstraints = false
    holder.heightAnchor.constraint(equalToConstant: 1).isActive = true

    let line = NSView()
    line.wantsLayer = true
    line.layer?.backgroundColor = Brand.separator.cgColor
    line.translatesAutoresizingMaskIntoConstraints = false
    holder.addSubview(line)
    NSLayoutConstraint.activate([
        line.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: leadingInset),
        line.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
        line.topAnchor.constraint(equalTo: holder.topAnchor),
        line.bottomAnchor.constraint(equalTo: holder.bottomAnchor)
    ])
    return holder
}

func brandStatusDot(on: Bool) -> NSView {
    let dot = NSView()
    dot.wantsLayer = true
    dot.translatesAutoresizingMaskIntoConstraints = false
    dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
    dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
    dot.layer?.cornerRadius = 5
    if on {
        dot.layer?.backgroundColor = Brand.led.cgColor
        dot.layer?.shadowColor = Brand.led.cgColor
        dot.layer?.shadowOpacity = 0.75
        dot.layer?.shadowRadius = 4
        dot.layer?.shadowOffset = .zero
        dot.layer?.masksToBounds = false
    } else {
        dot.layer?.backgroundColor = Brand.offDot.cgColor
        dot.layer?.borderWidth = 1
        dot.layer?.borderColor = Brand.offDotBorder.cgColor
    }
    return dot
}

final class GlassCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Brand.cardRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = Brand.surface.cgColor
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }
}

enum BrandIcon {
    static func make(diameter: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: diameter, height: diameter))
        image.lockFocus()
        let center = NSPoint(x: diameter / 2, y: diameter / 2)
        if let glow = NSGradient(colors: [
            Brand.ledBright.withAlphaComponent(0.95),
            Brand.led.withAlphaComponent(0.45),
            Brand.led.withAlphaComponent(0.0)
        ]) {
            glow.draw(fromCenter: center, radius: 0, toCenter: center, radius: diameter / 2, options: [])
        }
        Brand.led.setFill()
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

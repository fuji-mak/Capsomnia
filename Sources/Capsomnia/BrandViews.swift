import AppKit

enum DotImage {
    static func makeFilled(color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func makeRing(color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: 2.75, y: 2.75, width: 8.5, height: 8.5))
        ring.lineWidth = 1.5
        ring.stroke()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

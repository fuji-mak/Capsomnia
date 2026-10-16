import AppKit

/// A persistent, non-activating explanation shown only in an unlocked session.
final class LidOpenLockNotice: NSWindowController, NSWindowDelegate {
    private let onDismiss: () -> Void

    init(record: LidOpenLockRecord, onDismiss: @escaping () -> Void, onViewRecord: @escaping () -> Void) {
        self.onDismiss = onDismiss
        let text = LidOpenLockText.current
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 260),
                            styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Capsomnia · " + text.history
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = Brand.bg
        super.init(window: panel)
        panel.delegate = self

        let title = brandLabel(size: 17, weight: .semibold, color: Brand.led, wraps: true)
        title.stringValue = text.status(record)
        let detail = brandLabel(size: 12, color: Brand.text, wraps: true)
        detail.stringValue = text.details(record)
        let dismiss = LEDButton(height: 32)
        dismiss.title = text.acknowledge
        dismiss.onClick = { [weak self] in self?.close() }
        let view = LEDButton(height: 32)
        view.title = text.viewRecord
        view.onClick = { [weak self] in self?.close(); onViewRecord() }
        let buttons = NSStackView(views: [view, dismiss])
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        let stack = NSStackView(views: [title, detail, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        panel.contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        content.layoutSubtreeIfNeeded()
        panel.setContentSize(NSSize(width: 430, height: content.fittingSize.height))
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        guard let window else { return }
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            window.setFrameTopLeftPoint(NSPoint(x: frame.maxX - window.frame.width - 24, y: frame.maxY - 24))
        }
        // Do not activate the app or take keyboard focus from running work.
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) { onDismiss() }
}

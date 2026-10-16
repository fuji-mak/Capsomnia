import AppKit

/// Keep the key's cause until its requested system state is verified.
struct CapsLockFeedbackState {
    private(set) var pending: Bool?
    private var reportedFailure = false

    mutating func recordKey(previous: Bool, target: Bool) {
        guard previous != target else { return }
        pending = target
        reportedFailure = false
    }

    mutating func cancel() { pending = nil; reportedFailure = false }

    mutating func consume(target: Bool, succeeded: Bool) -> Bool {
        guard pending == target else { return false }
        if succeeded { cancel(); return true }
        guard !reportedFailure else { return false }
        reportedFailure = true
        return true
    }
}

private final class CapsLockFeedbackPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Click-through feedback that never takes focus from desktop automation.
final class CapsLockFeedbackNotice: NSWindowController {
    private var dismissal: DispatchWorkItem?

    init(target: Bool, succeeded: Bool, at date: Date, language: AppLanguage = Preferences.language) {
        let words: (on: String, off: String, failed: String, onDetail: String, offDetail: String, failureDetail: String)
        switch language {
        case .simplifiedChinese:
            words = ("已开启保持运行", "已关闭保持运行", "切换未成功", "防休眠已生效。", "已恢复系统原有的休眠行为。", "请打开 Capsomnia 查看当前状态。")
        case .english:
            words = ("Keep running enabled", "Keep running disabled", "Switch not confirmed", "Sleep prevention is active.", "Normal system sleep behavior restored.", "Open Capsomnia to check the current status.")
        case .japanese:
            words = ("動作を継続：オン", "動作を継続：オフ", "切り替えを確認できません", "スリープ防止が有効です。", "通常のスリープ動作に戻りました。", "Capsomnia を開いて状態を確認してください。")
        case .korean:
            words = ("계속 실행 켜짐", "계속 실행 꺼짐", "전환을 확인하지 못함", "잠자기 방지가 활성화되었습니다.", "기본 시스템 잠자기 동작으로 돌아갑니다.", "Capsomnia를 열어 현재 상태를 확인하세요.")
        }
        let panel = CapsLockFeedbackPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 150),
                                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = Brand.bg
        panel.hasShadow = true
        super.init(window: panel)

        let source = brandLabel(size: 12, color: Brand.textDim, wraps: true)
        source.stringValue = "Capsomnia · Caps Lock"
        let title = brandLabel(size: 18, weight: .semibold,
                               color: succeeded ? (target ? Brand.led : Brand.text) : .systemOrange, wraps: true)
        title.stringValue = succeeded ? (target ? words.on : words.off) : words.failed
        let detail = brandLabel(size: 13, color: Brand.text, wraps: true)
        detail.stringValue = succeeded ? (target ? words.onDetail : words.offDetail) : words.failureDetail
        let time = brandLabel(size: 12, color: Brand.textDim)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        time.stringValue = formatter.string(from: date)
        let stack = NSStackView(views: [source, title, detail, time])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 150))
        content.addSubview(stack)
        panel.contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ] + [source, title, detail, time].map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
        content.layoutSubtreeIfNeeded()
        panel.setContentSize(NSSize(width: 380, height: content.fittingSize.height))
    }

    required init?(coder: NSCoder) { nil }

    func present(duration: TimeInterval = 6) {
        guard let window else { return }
        dismissal?.cancel()
        if let frame = NSScreen.main?.visibleFrame {
            window.setFrameTopLeftPoint(NSPoint(x: frame.maxX - window.frame.width - 24, y: frame.maxY - 24))
        }
        window.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    override func close() { dismissal?.cancel(); dismissal = nil; super.close() }
    deinit { dismissal?.cancel() }
}

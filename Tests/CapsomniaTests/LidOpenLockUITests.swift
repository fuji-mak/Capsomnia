import AppKit
import XCTest
@testable import Capsomnia

@MainActor
final class LidOpenLockUITests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    func testSwitchFollowsParentAndHistoryShowsConfirmedTimesInEveryLanguage() throws {
        _ = NSApplication.shared
        let previousLanguage = Preferences.language
        let previousParent = Preferences.keepDisplayAwake
        let previousEnabled = Preferences.lockOnLidOpen
        defer {
            Preferences.language = previousLanguage
            Preferences.keepDisplayAwake = previousParent
            Preferences.lockOnLidOpen = previousEnabled
        }
        let date = Date(timeIntervalSince1970: 1_791_873_128)
        let record = LidOpenLockRecord(id: UUID(), openedAt: date, closedAt: date.addingTimeInterval(-3600), requestedAt: date,
                                      confirmedAt: date.addingTimeInterval(0.5), outcome: .locked)
        var toggles = 0
        let controller = SettingsWindowController(
            onDedicatedCapsLockModeChange: { _ in }, onShowMenuBarIconChange: { _ in },
            onLanguageChange: { _ in }, onLaunchAtLoginChange: { _ in },
            onKeepDisplayAwakeChange: { _ in }, onKeepHotspotAliveChange: { _ in },
            onIgnoreExternalCapsLockOffWhileLidClosedChange: { _ in }, onHideCapsLockIndicatorChange: { _ in },
            capsLockIndicatorStateProvider: { .init(hidden: false, restartPending: false) },
            onAutoOffMinutesChange: { _ in }, onAutoOffRestart: {}, autoOffDisplayProvider: { .idle(minutes: 0) },
            onKeyboardShortcutChange: { _ in true }, onKeyboardShortcutRecordingChange: { _ in },
            onAutomaticUpdateChecksChange: { _ in }, onFinishInitialSetup: {}, onLidOpenLockChange: { value in
                toggles += 1
                Preferences.lockOnLidOpen = value
            }, lidLockRecordProvider: { record }, awakeModeProvider: { true })
        defer { controller.close() }
        for language in AppLanguage.allCases {
            Preferences.language = language
            Preferences.keepDisplayAwake = false
            Preferences.lockOnLidOpen = true
            controller.show(page: .settings)
            let content = try XCTUnwrap(controller.window?.contentView)
            let toggle = try XCTUnwrap(descendants(content).compactMap { $0 as? LEDToggle }.first {
                $0.accessibilityLabel() == LidOpenLockText.current.title
            })
            XCTAssertFalse(toggle.isEnabled)
            XCTAssertTrue(toggle.isOn, "Turning off the parent preserves the user's selection")
            XCTAssertFalse(toggle.accessibilityPerformPress())
            let before = toggles
            Preferences.keepDisplayAwake = true
            controller.refreshLidLockRecord()
            XCTAssertTrue(toggle.isEnabled)
            XCTAssertTrue(toggle.accessibilityPerformPress())
            XCTAssertEqual(toggles, before + 1)
            content.layoutSubtreeIfNeeded()
            XCTAssertTrue(content.bounds.contains(toggle.convert(toggle.bounds, to: content)))
            if language == .simplifiedChinese { try capture(content, name: "lid-lock-settings") }
            controller.show(page: .advancedSettings)
            let text = LidOpenLockText.current
            let detail = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTextField }.first {
                $0.stringValue.contains(text.verified)
            })
            XCTAssertTrue(detail.stringValue.contains(text.reason))
            XCTAssertTrue(detail.stringValue.contains("2026-"))
            content.layoutSubtreeIfNeeded()
            XCTAssertTrue(content.bounds.contains(detail.convert(detail.bounds, to: content)))
            if language == .simplifiedChinese { try capture(content, name: "lid-lock-record") }
        }
    }

    func testUnlockNoticeContainsCauseAndTimesWithoutKeyWindowActivation() throws {
        _ = NSApplication.shared
        let previous = Preferences.language
        Preferences.language = .simplifiedChinese
        defer { Preferences.language = previous }
        let now = Date(timeIntervalSince1970: 1_791_873_128)
        let record = LidOpenLockRecord(id: UUID(), openedAt: now, closedAt: now.addingTimeInterval(-3600), requestedAt: now,
                                      confirmedAt: now.addingTimeInterval(1), outcome: .locked)
        var acknowledged = 0
        let notice = LidOpenLockNotice(record: record, onDismiss: { acknowledged += 1 }, onViewRecord: {})
        let content = try XCTUnwrap(notice.window?.contentView)
        let text = descendants(content).compactMap { $0 as? NSTextField }.map(\.stringValue).joined(separator: "\n")
        XCTAssertTrue(text.contains("因开盖自动锁定"))
        XCTAssertTrue(text.contains("最近一次合盖"))
        XCTAssertTrue(text.contains("检测到开盖"))
        XCTAssertFalse(text.contains("请求锁定："))
        XCTAssertTrue(text.contains("确认已锁定"))
        XCTAssertTrue(text.contains("2026-"))
        XCTAssertFalse(notice.window?.isKeyWindow ?? true)
        content.layoutSubtreeIfNeeded()
        try capture(content, name: "lid-lock-notice")
        notice.close()
        XCTAssertEqual(acknowledged, 1)
    }

    private func capture(_ view: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CAPSOMNIA_UI_CAPTURE_DIR"] else { return }
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
    }
}

import AppKit
import XCTest
@testable import Capsomnia

@MainActor
final class LidOpenLockUITests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    func testCheckboxAppearsOnlyWithComputerUseAndPreservesSelectionInEveryLanguage() throws {
        _ = NSApplication.shared
        let previousLanguage = Preferences.language
        let previousParent = Preferences.keepDisplayAwake
        let previousEnabled = Preferences.lockOnLidOpen
        defer {
            Preferences.language = previousLanguage
            Preferences.keepDisplayAwake = previousParent
            Preferences.lockOnLidOpen = previousEnabled
        }
        var toggles = 0
        let controller = SettingsWindowController(
            onDedicatedCapsLockModeChange: { _ in }, onShowMenuBarIconChange: { _ in },
            onLanguageChange: { _ in }, onLaunchAtLoginChange: { _ in },
            onKeepDisplayAwakeChange: { Preferences.keepDisplayAwake = $0 }, onKeepHotspotAliveChange: { _ in },
            onIgnoreExternalCapsLockOffWhileLidClosedChange: { _ in }, onHideCapsLockIndicatorChange: { _ in },
            capsLockIndicatorStateProvider: { .init(hidden: false, restartPending: false) },
            onAutoOffMinutesChange: { _ in }, onAutoOffRestart: {}, autoOffDisplayProvider: { .idle(minutes: 0) },
            onKeyboardShortcutChange: { _ in true }, onKeyboardShortcutRecordingChange: { _ in },
            onAutomaticUpdateChecksChange: { _ in }, onFinishInitialSetup: {}, onLidOpenLockChange: { value in
                toggles += 1
                Preferences.lockOnLidOpen = value
            })
        defer { controller.close() }
        for language in AppLanguage.allCases {
            Preferences.language = language
            Preferences.keepDisplayAwake = false
            Preferences.lockOnLidOpen = true
            controller.updateHeaderStatus(.on)
            controller.show(page: .settings)
            let content = try XCTUnwrap(controller.window?.contentView)
            let checkbox = try XCTUnwrap(descendants(content).compactMap { $0 as? NSButton }.first {
                $0.accessibilityLabel() == LidOpenLockText.current.title
            })
            let parent = try XCTUnwrap(descendants(content).compactMap { $0 as? LEDToggle }.first {
                $0.accessibilityLabel() == AppStrings.current().keepDisplayAwake
            })
            content.layoutSubtreeIfNeeded()
            let hiddenHeight = content.bounds.height
            XCTAssertTrue(checkbox.isHiddenOrHasHiddenAncestor)
            XCTAssertFalse(checkbox.isEnabled)
            XCTAssertEqual(checkbox.state, .on, "Hiding the option preserves the user's selection")
            if language == .japanese { try capture(content, name: "lid-lock-disabled-ja") }

            XCTAssertTrue(parent.accessibilityPerformPress())
            content.layoutSubtreeIfNeeded()
            XCTAssertFalse(checkbox.isHiddenOrHasHiddenAncestor)
            XCTAssertTrue(checkbox.isEnabled)
            XCTAssertEqual(checkbox.state, .on)
            XCTAssertGreaterThan(content.bounds.height, hiddenHeight)
            let checkboxFrame = checkbox.convert(checkbox.bounds, to: content)
            XCTAssertTrue(content.bounds.contains(checkboxFrame))
            let title = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTextField }.first {
                $0.stringValue == AppStrings.current().keepDisplayAwake
            })
            XCTAssertGreaterThan(checkboxFrame.minX, title.convert(title.bounds, to: content).minX)
            if language == .japanese { try capture(content, name: "lid-lock-enabled-ja") }
            let before = toggles
            checkbox.performClick(nil)
            XCTAssertFalse(Preferences.lockOnLidOpen)
            XCTAssertEqual(toggles, before + 1)
            checkbox.performClick(nil)
            XCTAssertTrue(Preferences.lockOnLidOpen)

            XCTAssertTrue(parent.accessibilityPerformPress())
            content.layoutSubtreeIfNeeded()
            XCTAssertTrue(checkbox.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(checkbox.state, .on)
            XCTAssertTrue(Preferences.lockOnLidOpen)
            XCTAssertEqual(content.bounds.height, hiddenHeight, accuracy: 1, "Hidden options leave no extra space")
            XCTAssertTrue(parent.accessibilityPerformPress())
            XCTAssertFalse(checkbox.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(checkbox.state, .on)
            controller.show(page: .advancedSettings)
            content.layoutSubtreeIfNeeded()
            if language == .japanese { try capture(content, name: "lid-lock-advanced-ja") }
        }
    }

    private func capture(_ view: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CAPSOMNIA_UI_CAPTURE_DIR"] else { return }
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
    }
}

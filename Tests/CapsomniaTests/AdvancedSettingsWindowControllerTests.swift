import AppKit
import XCTest
@testable import Capsomnia

@MainActor
final class AdvancedSettingsWindowControllerTests: XCTestCase {
    func testJapaneseAdvancedSettingsContainsMovedOptionsAndShortcutPreview() throws {
        let previousLanguage = Preferences.language
        Preferences.language = .japanese
        defer { Preferences.language = previousLanguage }
        let strings = AppStrings.localized(for: .japanese)

        _ = NSApplication.shared
        let controller = AdvancedSettingsWindowController(
            onLaunchAtLoginChange: { _ in },
            onDisplaySleepOnLidCloseChange: { _ in }
        )
        defer { controller.close() }

        let contentView = try XCTUnwrap(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()

        let labels: [NSTextField] = descendants(of: contentView)
        let renderedText = Set(labels.map(\.stringValue))
        for expected in [
            strings.advancedSettingsTitle,
            strings.advancedSettingsSubtitle,
            strings.systemBehavior.uppercased(),
            strings.displaySleepOnLidClose,
            strings.openAtLogin,
            strings.keyboardShortcut.uppercased(),
            strings.keyboardShortcutDesc,
            strings.shortcutPreviewNote,
            strings.done
        ] {
            XCTAssertTrue(renderedText.contains(expected), "Missing rendered text: \(expected)")
        }

        let recorder: ShortcutRecorderButton = try XCTUnwrap(
            descendants(of: contentView).first
        )
        XCTAssertEqual(recorder.title, strings.shortcutRecorderPlaceholder)
        XCTAssertEqual(recorder.accessibilityLabel(), strings.keyboardShortcut)
        XCTAssertEqual(recorder.accessibilityHelp(), strings.shortcutPreviewNote)

        for label in labels where !label.stringValue.isEmpty {
            let frame = label.convert(label.bounds, to: contentView)
            XCTAssertGreaterThanOrEqual(frame.minX, -1, "\(label.stringValue) starts outside the window")
            XCTAssertLessThanOrEqual(
                frame.maxX,
                contentView.bounds.maxX + 1,
                "\(label.stringValue) extends outside the window"
            )
        }
    }

    private func descendants<T: NSView>(of view: NSView) -> [T] {
        view.subviews.flatMap { child -> [T] in
            let current = (child as? T).map { [$0] } ?? []
            return current + descendants(of: child)
        }
    }
}

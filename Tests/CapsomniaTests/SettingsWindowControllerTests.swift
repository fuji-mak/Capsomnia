import AppKit
import XCTest
@testable import Capsomnia

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testJapaneseInitialSetupHidesDefaultOnSettings() throws {
        let previousLanguage = Preferences.language
        let previousShortcut = Preferences.keyboardShortcut
        Preferences.language = .japanese
        Preferences.keyboardShortcut = nil
        defer {
            Preferences.language = previousLanguage
            Preferences.keyboardShortcut = previousShortcut
        }
        let strings = AppStrings.localized(for: .japanese)

        _ = NSApplication.shared
        let controller = makeController()
        defer { controller.close() }

        controller.show(page: .initialPreferences)
        let contentView = try XCTUnwrap(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()

        var renderedText = Set(
            (visibleDescendants(of: contentView) as [NSTextField]).map(\.stringValue)
        )
        XCTAssertTrue(renderedText.contains(strings.initialPreferencesHeading))
        XCTAssertTrue(renderedText.contains(strings.dedicatedCapsLockMode))
        XCTAssertFalse(renderedText.contains(strings.preferencesHeading))
        XCTAssertFalse(renderedText.contains(strings.displaySleepOnLidClose))
        XCTAssertFalse(renderedText.contains(strings.openAtLogin))
        var visibleButtons: [DisclosureButton] = visibleDescendants(of: contentView)
        XCTAssertFalse(
            visibleButtons.contains {
                $0.accessibilityLabel() == strings.advancedSettings
            }
        )

        controller.show(page: .settings)
        contentView.layoutSubtreeIfNeeded()

        renderedText = Set(
            (visibleDescendants(of: contentView) as [NSTextField]).map(\.stringValue)
        )
        XCTAssertTrue(renderedText.contains(strings.preferencesHeading))
        XCTAssertFalse(renderedText.contains(strings.displaySleepOnLidClose))
        XCTAssertFalse(renderedText.contains(strings.openAtLogin))
        XCTAssertFalse(renderedText.contains(strings.autoOffTimer.uppercased()))
        visibleButtons = visibleDescendants(of: contentView)
        XCTAssertTrue(
            visibleButtons.contains {
                $0.accessibilityLabel() == strings.advancedSettings
            }
        )
        let advancedSettingsButton = try XCTUnwrap(visibleButtons.first)
        XCTAssertNil(advancedSettingsButton.accessibilityHelp())
        XCTAssertTrue(advancedSettingsButton.accessibilityPerformPress())
        XCTAssertEqual(controller.window?.title, strings.advancedSettings)
    }

    func testKoreanSettingsRenderWithinTheWindow() throws {
        let previousLanguage = Preferences.language
        Preferences.language = .korean
        defer { Preferences.language = previousLanguage }
        let strings = AppStrings.localized(for: .korean)

        _ = NSApplication.shared
        let controller = makeController()
        let contentView = try XCTUnwrap(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()

        let labels: [NSTextField] = descendants(of: contentView)
        let renderedText = Set(labels.map(\.stringValue))

        for expected in [
            strings.dedicatedCapsLockMode,
            strings.showMenuBarIcon,
            strings.language,
            strings.advancedSettings,
            strings.done
        ] {
            XCTAssertTrue(renderedText.contains(expected), "Missing rendered text: \(expected)")
        }
        XCTAssertFalse(renderedText.contains(strings.displaySleepOnLidClose))
        XCTAssertFalse(renderedText.contains(strings.openAtLogin))
        XCTAssertFalse(renderedText.contains(strings.autoOffTimer.uppercased()))

        let buttons: [DisclosureButton] = descendants(of: contentView)
        XCTAssertTrue(
            buttons.contains {
                $0.accessibilityLabel() == strings.advancedSettings
            }
        )

        let languagePopUp: LanguagePopUpButton = try XCTUnwrap(descendants(of: contentView).first)
        XCTAssertEqual(languagePopUp.selectedValue, AppLanguage.korean.rawValue)
        XCTAssertEqual(languagePopUp.titleOfSelectedItem, AppLanguage.korean.displayName)
        XCTAssertEqual(languagePopUp.accessibilityLabel(), "언어")

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

    func testKoreanLanguageIsAvailableInThePopUp() throws {
        let previousLanguage = Preferences.language
        Preferences.language = .english
        defer { Preferences.language = previousLanguage }

        _ = NSApplication.shared
        let controller = makeController()
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let languagePopUp: LanguagePopUpButton = try XCTUnwrap(descendants(of: contentView).first)

        XCTAssertEqual(languagePopUp.itemTitles, ["English", "日本語", "简体中文", "한국어"])
        XCTAssertEqual(languagePopUp.selectedValue, AppLanguage.english.rawValue)

        languagePopUp.setSelected(AppLanguage.korean.rawValue)

        XCTAssertEqual(languagePopUp.selectedValue, AppLanguage.korean.rawValue)
        XCTAssertEqual(languagePopUp.titleOfSelectedItem, AppLanguage.korean.displayName)
    }

    func testAdvancedSettingsReplacesContentInTheSameLargerWindow() throws {
        let previousLanguage = Preferences.language
        let previousShortcut = Preferences.keyboardShortcut
        Preferences.language = .japanese
        Preferences.keyboardShortcut = nil
        defer {
            Preferences.language = previousLanguage
            Preferences.keyboardShortcut = previousShortcut
        }
        let strings = AppStrings.localized(for: .japanese)

        _ = NSApplication.shared
        let controller = makeController()
        defer { controller.close() }

        controller.show(page: .settings)
        let originalWindow = try XCTUnwrap(controller.window)
        let basicWidth = originalWindow.contentView?.bounds.width ?? 0

        controller.show(page: .advancedSettings)
        let advancedWindow = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(advancedWindow.contentView)
        contentView.layoutSubtreeIfNeeded()

        XCTAssertTrue(originalWindow === advancedWindow)
        XCTAssertGreaterThan(contentView.bounds.width, basicWidth)
        XCTAssertEqual(advancedWindow.title, strings.advancedSettings)

        let visibleLabels: [NSTextField] = visibleDescendants(of: contentView)
        let renderedText = Set(visibleLabels.map(\NSTextField.stringValue))
        for expected in [
            strings.advancedSettings,
            strings.preferencesHeading.uppercased(),
            strings.showMenuBarIcon,
            strings.dedicatedCapsLockMode,
            strings.language,
            strings.systemBehavior.uppercased(),
            strings.displaySleepOnLidClose,
            strings.openAtLogin,
            strings.autoOffTimer.uppercased(),
            strings.autoOffOff,
            strings.autoOffCustom,
            strings.keyboardShortcut.uppercased(),
            strings.keyboardShortcut,
            strings.keyboardShortcutDesc
        ] {
            XCTAssertTrue(renderedText.contains(expected), "Missing rendered text: \(expected)")
        }

        let preferencesHeading = try XCTUnwrap(
            visibleLabels.first { $0.stringValue == strings.preferencesHeading.uppercased() }
        )
        let timerHeading = try XCTUnwrap(
            visibleLabels.first { $0.stringValue == strings.autoOffTimer.uppercased() }
        )
        let shortcutHeading = try XCTUnwrap(
            visibleLabels.first { $0.stringValue == strings.keyboardShortcut.uppercased() }
        )
        let preferencesFrame = preferencesHeading.convert(preferencesHeading.bounds, to: contentView)
        let timerFrame = timerHeading.convert(timerHeading.bounds, to: contentView)
        let shortcutFrame = shortcutHeading.convert(shortcutHeading.bounds, to: contentView)
        XCTAssertGreaterThan(
            timerFrame.minX,
            preferencesFrame.maxX,
            "The timer column should be to the right of the general settings column"
        )
        XCTAssertEqual(
            shortcutFrame.minX,
            timerFrame.minX,
            accuracy: 1,
            "The shortcut should share the timer's right column"
        )
        XCTAssertLessThan(
            shortcutFrame.minY,
            timerFrame.minY,
            "The shortcut should appear below the timer"
        )

        let recorder: ShortcutRecorderButton = try XCTUnwrap(
            visibleDescendants(of: contentView).first
        )
        XCTAssertEqual(recorder.title, strings.shortcutRecorderPlaceholder)
        XCTAssertEqual(recorder.accessibilityLabel(), strings.keyboardShortcut)
        XCTAssertEqual(recorder.accessibilityHelp(), strings.keyboardShortcutDesc)

        let backButtons: [NSButton] = visibleDescendants(of: contentView)
        XCTAssertTrue(
            backButtons.contains {
                $0.accessibilityLabel() == strings.settingsTitle
            }
        )
    }

    func testClosingWindowCancelsShortcutRecording() throws {
        _ = NSApplication.shared
        var recordingStates: [Bool] = []
        let controller = makeController(
            onKeyboardShortcutRecordingChange: {
                recordingStates.append($0)
            }
        )

        controller.show(page: .advancedSettings)
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let recorder: ShortcutRecorderButton = try XCTUnwrap(
            visibleDescendants(of: contentView).first
        )
        XCTAssertTrue(recorder.accessibilityPerformPress())

        controller.close()

        XCTAssertEqual(recordingStates, [true, false])
    }

    func testAutoOffCustomEditorDoesNotResizeOrShiftTheSettingsWindow() throws {
        let previousLanguage = Preferences.language
        let previousMinutes = Preferences.autoOffMinutes
        Preferences.language = .english
        Preferences.autoOffMinutes = 60
        defer {
            Preferences.language = previousLanguage
            Preferences.autoOffMinutes = previousMinutes
        }
        let strings = AppStrings.localized(for: .english)

        _ = NSApplication.shared
        let controller = makeController(
            autoOffDisplayProvider: { .counting(remaining: 45 * 60) }
        )
        defer { controller.close() }

        controller.show(page: .advancedSettings)
        let contentView = try XCTUnwrap(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()

        let timerControl: AutoOffTimerControl = try XCTUnwrap(descendants(of: contentView).first)
        let customChip = try XCTUnwrap(
            view(in: contentView, accessibilityLabel: strings.autoOffCustom)
        )
        let preferencesHeading = try XCTUnwrap(
            visibleDescendants(of: contentView).first {
                $0.stringValue == strings.preferencesHeading.uppercased()
            } as NSTextField?
        )
        let originalContentSize = contentView.bounds.size
        let originalPreferencesFrame = preferencesHeading.convert(
            preferencesHeading.bounds,
            to: contentView
        )

        XCTAssertTrue(customChip.accessibilityPerformPress())
        contentView.layoutSubtreeIfNeeded()

        XCTAssertTrue(timerControl.isCustomEditorVisible)
        XCTAssertEqual(contentView.bounds.size, originalContentSize)
        XCTAssertEqual(
            preferencesHeading.convert(preferencesHeading.bounds, to: contentView),
            originalPreferencesFrame
        )

        let labels: [NSTextField] = descendants(of: contentView)
        let renderedText = Set(labels.map(\.stringValue))

        // The timer stays in the right column; custom controls live in a separate popover.
        XCTAssertTrue(renderedText.contains(strings.autoOffTimer.uppercased()))
        XCTAssertTrue(renderedText.contains(strings.autoOffOff))
        XCTAssertTrue(renderedText.contains(strings.autoOffCustom))
        XCTAssertFalse(renderedText.contains(strings.autoOffHours))
        XCTAssertFalse(renderedText.contains(strings.autoOffMinutesUnit))
        XCTAssertTrue(renderedText.contains("1h"))
        XCTAssertTrue(renderedText.contains("8h"))
        XCTAssertTrue(renderedText.contains("00:45:00"))

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

    func testRestartButtonShownWhenTimerIsSetAndHiddenWhenOff() throws {
        let previousLanguage = Preferences.language
        let previousMinutes = Preferences.autoOffMinutes
        Preferences.language = .english
        defer {
            Preferences.language = previousLanguage
            Preferences.autoOffMinutes = previousMinutes
        }
        let restartLabel = AppStrings.localized(for: .english).autoOffRestart
        _ = NSApplication.shared

        // A finite timer -> the restart icon is available.
        Preferences.autoOffMinutes = 45
        let onController = makeController()
        defer { onController.close() }
        onController.show(page: .advancedSettings)
        let onContent = try XCTUnwrap(onController.window?.contentView)
        onContent.layoutSubtreeIfNeeded()
        let shown = try XCTUnwrap(view(in: onContent, accessibilityLabel: restartLabel))
        XCTAssertFalse(shown.isHidden, "Restart icon should be available when a timer is set")

        // No timer (Off) -> the restart icon is hidden.
        Preferences.autoOffMinutes = 0
        let offController = makeController()
        defer { offController.close() }
        offController.show(page: .advancedSettings)
        let offContent = try XCTUnwrap(offController.window?.contentView)
        offContent.layoutSubtreeIfNeeded()
        let hidden = try XCTUnwrap(view(in: offContent, accessibilityLabel: restartLabel))
        XCTAssertTrue(hidden.isHidden, "Restart icon should be hidden when the timer is Off")
    }

    private func view(in view: NSView, accessibilityLabel: String) -> NSView? {
        let all: [NSView] = descendants(of: view)
        return all.first { $0.accessibilityLabel() == accessibilityLabel }
    }

    private func makeController(
        onKeyboardShortcutRecordingChange: @escaping (Bool) -> Void = { _ in },
        autoOffDisplayProvider: @escaping () -> AutoOffDisplayState = { .idle(minutes: 0) }
    ) -> SettingsWindowController {
        SettingsWindowController(
            onDedicatedCapsLockModeChange: { _ in },
            onShowMenuBarIconChange: { _ in },
            onLanguageChange: { _ in },
            onLaunchAtLoginChange: { _ in },
            onDisplaySleepOnLidCloseChange: { _ in },
            onAutoOffMinutesChange: { _ in },
            onAutoOffRestart: {},
            autoOffDisplayProvider: autoOffDisplayProvider,
            onKeyboardShortcutChange: { _ in true },
            onKeyboardShortcutRecordingChange: onKeyboardShortcutRecordingChange,
            onFinishInitialSetup: {}
        )
    }

    private func descendants<T: NSView>(of view: NSView) -> [T] {
        view.subviews.flatMap { child -> [T] in
            let current = (child as? T).map { [$0] } ?? []
            return current + descendants(of: child)
        }
    }

    private func visibleDescendants<T: NSView>(of view: NSView) -> [T] {
        view.subviews.flatMap { child -> [T] in
            guard !child.isHidden else { return [] }
            let current = (child as? T).map { [$0] } ?? []
            return current + visibleDescendants(of: child)
        }
    }
}

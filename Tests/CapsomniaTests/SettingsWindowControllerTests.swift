import AppKit
import XCTest
@testable import Capsomnia

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testJapaneseInitialSetupHidesDefaultOnSettings() throws {
        let previousLanguage = Preferences.language
        Preferences.language = .japanese
        defer { Preferences.language = previousLanguage }
        let strings = AppStrings.localized(for: .japanese)

        _ = NSApplication.shared
        let controller = makeController()
        defer { controller.close() }

        controller.show(page: .initialPreferences)
        let contentView = try XCTUnwrap(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()

        var renderedText = Set(visibleDescendants(of: contentView).map(\NSTextField.stringValue))
        XCTAssertTrue(renderedText.contains(strings.initialPreferencesHeading))
        XCTAssertTrue(renderedText.contains(strings.dedicatedCapsLockMode))
        XCTAssertFalse(renderedText.contains(strings.preferencesHeading))
        XCTAssertFalse(renderedText.contains(strings.displaySleepOnLidClose))
        XCTAssertFalse(renderedText.contains(strings.openAtLogin))

        controller.show(page: .settings)
        contentView.layoutSubtreeIfNeeded()

        renderedText = Set(visibleDescendants(of: contentView).map(\NSTextField.stringValue))
        XCTAssertTrue(renderedText.contains(strings.preferencesHeading))
        XCTAssertTrue(renderedText.contains(strings.displaySleepOnLidClose))
        XCTAssertTrue(renderedText.contains(strings.openAtLogin))
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
            strings.displaySleepOnLidClose,
            strings.openAtLogin,
            "Language",
            strings.done
        ] {
            XCTAssertTrue(renderedText.contains(expected), "Missing rendered text: \(expected)")
        }

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

    private func makeController() -> SettingsWindowController {
        SettingsWindowController(
            onDedicatedCapsLockModeChange: { _ in },
            onShowMenuBarIconChange: { _ in },
            onLanguageChange: { _ in },
            onLaunchAtLoginChange: { _ in },
            onDisplaySleepOnLidCloseChange: { _ in },
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

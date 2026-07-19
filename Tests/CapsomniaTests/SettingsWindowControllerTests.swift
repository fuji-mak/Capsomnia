import AppKit
import XCTest
@testable import Capsomnia

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testKoreanSettingsRenderWithinTheWindow() throws {
        let previousLanguage = Preferences.language
        Preferences.language = .korean
        defer { Preferences.language = previousLanguage }

        _ = NSApplication.shared
        let controller = makeController()
        let contentView = try XCTUnwrap(controller.window?.contentView)
        contentView.layoutSubtreeIfNeeded()

        let labels: [NSTextField] = descendants(of: contentView)
        let renderedText = Set(labels.map(\.stringValue))

        for expected in [
            "Caps Lock 전용 스위치",
            "메뉴 막대에 표시",
            "덮개를 닫을 때 화면 끄기",
            "로그인할 때 열기",
            "Language",
            "완료"
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
}

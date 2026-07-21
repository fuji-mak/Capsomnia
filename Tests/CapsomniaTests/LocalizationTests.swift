import XCTest
@testable import Capsomnia

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageSelectsSupportedLanguage() {
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "en-US"), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "ja-JP"), .japanese)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "zh-Hans-CN"), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "ko-KR"), .korean)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "ko_KR"), .korean)
    }

    func testPreferredLanguageFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "fr-FR"), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "kok-IN"), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "jav-ID"), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: nil), .english)
    }

    func testEveryLanguageHasSettingsStrings() {
        for language in AppLanguage.allCases {
            let strings = AppStrings.localized(for: language)

            XCTAssertFalse(strings.settingsTitle.isEmpty)
            XCTAssertFalse(strings.dedicatedCapsLockMode.isEmpty)
            XCTAssertFalse(strings.dedicatedCapsLockModeDesc.isEmpty)
            XCTAssertFalse(strings.toggleCapsLock.isEmpty)
            XCTAssertFalse(strings.showMenuBarIcon.isEmpty)
            XCTAssertFalse(strings.displaySleepOnLidClose.isEmpty)
            XCTAssertFalse(strings.openAtLogin.isEmpty)
            XCTAssertFalse(strings.language.isEmpty)
            XCTAssertFalse(strings.advancedSettings.isEmpty)
            XCTAssertFalse(strings.advancedSettingsDesc.isEmpty)
            XCTAssertFalse(strings.systemBehavior.isEmpty)
            XCTAssertFalse(strings.keyboardShortcut.isEmpty)
            XCTAssertFalse(strings.keyboardShortcutDesc.isEmpty)
            XCTAssertFalse(strings.shortcutRecorderPlaceholder.isEmpty)
            XCTAssertFalse(strings.shortcutRecorderRecording.isEmpty)
            XCTAssertFalse(strings.shortcutRecorderAction.isEmpty)
            XCTAssertFalse(strings.shortcutRegistrationFailed.isEmpty)
            XCTAssertFalse(strings.initialPreferencesHeading.isEmpty)
            XCTAssertFalse(strings.done.isEmpty)
            XCTAssertFalse(strings.tooltipDedicatedPermission.isEmpty)
        }
    }

    func testSimplifiedChineseStrings() {
        let strings = AppStrings.localized(for: .simplifiedChinese)

        XCTAssertEqual(AppLanguage.simplifiedChinese.displayName, "简体中文")
        XCTAssertEqual(strings.language, "语言")
        XCTAssertEqual(strings.settingsTitle, "设置")
        XCTAssertEqual(strings.getStarted, "开始使用")
    }

    func testKoreanStrings() {
        let strings = AppStrings.localized(for: .korean)

        XCTAssertEqual(AppLanguage.korean.displayName, "한국어")
        XCTAssertEqual(strings.language, "언어")
        XCTAssertEqual(strings.settingsTitle, "설정")
        XCTAssertEqual(strings.explainerOnTitle, "Caps Lock 켜기")
        XCTAssertEqual(strings.explainerOffTitle, "Caps Lock 끄기")
    }

    func testLanguagePopUpTracksSelectedLanguage() {
        let popUp = LanguagePopUpButton(
            items: AppLanguage.allCases.map { (title: $0.displayName, value: $0.rawValue) },
            selected: AppLanguage.japanese.rawValue
        )

        XCTAssertEqual(popUp.itemTitles, ["English", "日本語", "简体中文", "한국어"])
        XCTAssertEqual(popUp.selectedValue, AppLanguage.japanese.rawValue)

        popUp.setSelected(AppLanguage.korean.rawValue)

        XCTAssertEqual(popUp.selectedValue, AppLanguage.korean.rawValue)
        XCTAssertEqual(popUp.titleOfSelectedItem, AppLanguage.korean.displayName)
    }
}

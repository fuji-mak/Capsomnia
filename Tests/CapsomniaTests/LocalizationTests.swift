import XCTest
@testable import Capsomnia

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageSelectsKoreanAndJapanese() {
        XCTAssertEqual(AppLanguage.preferredLanguage(from: ["ko-KR"]), .korean)
        XCTAssertEqual(AppLanguage.preferredLanguage(from: ["ja-JP"]), .japanese)
    }

    func testPreferredLanguageFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.preferredLanguage(from: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.preferredLanguage(from: ["kok-IN"]), .english)
        XCTAssertEqual(AppLanguage.preferredLanguage(from: ["jav-ID"]), .english)
        XCTAssertEqual(AppLanguage.preferredLanguage(from: []), .english)
    }

    func testEveryLanguageHasSettingsStrings() {
        for language in AppLanguage.allCases {
            let strings = AppStrings.localized(for: language)

            XCTAssertFalse(strings.settingsTitle.isEmpty)
            XCTAssertFalse(strings.showMenuBarIcon.isEmpty)
            XCTAssertFalse(strings.displaySleepOnLidClose.isEmpty)
            XCTAssertFalse(strings.openAtLogin.isEmpty)
            XCTAssertFalse(strings.language.isEmpty)
            XCTAssertFalse(strings.done.isEmpty)
        }
    }

    func testKoreanStringsAreAvailable() {
        let strings = AppStrings.localized(for: .korean)

        XCTAssertEqual(AppLanguage.korean.displayName, "한국어")
        XCTAssertEqual(strings.settingsTitle, "설정")
        XCTAssertEqual(strings.explainerOnTitle, "Caps Lock 켜기")
        XCTAssertEqual(strings.explainerOffTitle, "Caps Lock 끄기")
    }
}

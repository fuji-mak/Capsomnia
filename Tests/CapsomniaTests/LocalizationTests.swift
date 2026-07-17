import XCTest
@testable import Capsomnia

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageSelectsSupportedLanguage() {
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "en-US"), .english)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "ja-JP"), .japanese)
        XCTAssertEqual(AppLanguage.defaultLanguage(for: "zh-Hans-CN"), .simplifiedChinese)
    }

    func testSimplifiedChineseStrings() {
        let strings = AppStrings.localized(for: .simplifiedChinese)

        XCTAssertEqual(AppLanguage.simplifiedChinese.displayName, "简体中文")
        XCTAssertEqual(strings.language, "语言")
        XCTAssertEqual(strings.settingsTitle, "设置")
        XCTAssertEqual(strings.getStarted, "开始使用")
    }

    func testLanguagePopUpTracksSelectedLanguage() {
        let popUp = LanguagePopUpButton(
            items: AppLanguage.allCases.map { (title: $0.displayName, value: $0.rawValue) },
            selected: AppLanguage.japanese.rawValue
        )

        XCTAssertEqual(popUp.itemTitles, ["English", "日本語", "简体中文"])
        XCTAssertEqual(popUp.selectedValue, AppLanguage.japanese.rawValue)

        popUp.setSelected(AppLanguage.simplifiedChinese.rawValue)

        XCTAssertEqual(popUp.selectedValue, AppLanguage.simplifiedChinese.rawValue)
        XCTAssertEqual(popUp.titleOfSelectedItem, AppLanguage.simplifiedChinese.displayName)
    }
}

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
}

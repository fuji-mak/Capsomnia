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
            "메뉴 막대에 표시",
            "덮개를 닫을 때 화면 끄기",
            "로그인할 때 열기",
            "언어",
            "한국어",
            "완료"
        ] {
            XCTAssertTrue(renderedText.contains(expected), "Missing rendered text: \(expected)")
        }

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

    func testKoreanLanguageSegmentHandlesASelection() throws {
        let previousLanguage = Preferences.language
        Preferences.language = .english
        defer { Preferences.language = previousLanguage }

        _ = NSApplication.shared
        let controller = makeController()
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let languageSegment: SegmentedPill = try XCTUnwrap(descendants(of: contentView).first)
        let koreanButton: ClickableView = try XCTUnwrap(
            descendants(of: languageSegment).first { button in
                let labels: [NSTextField] = descendants(of: button)
                return labels.contains { $0.stringValue == "한국어" }
            }
        )
        var selectedLanguage: String?
        languageSegment.onSelect = { selectedLanguage = $0 }

        koreanButton.onClick?()

        XCTAssertEqual(languageSegment.selectedValue, "ko")
        XCTAssertEqual(selectedLanguage, "ko")
    }

    private func makeController() -> SettingsWindowController {
        SettingsWindowController(
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

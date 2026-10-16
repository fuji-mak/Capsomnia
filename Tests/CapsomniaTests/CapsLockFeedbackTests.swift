import AppKit
import XCTest
@testable import Capsomnia

final class CapsLockFeedbackTests: XCTestCase {
    func testOnlyConfirmedMatchingKeyChangesProduceOneSuccess() {
        var feedback = CapsLockFeedbackState()
        XCTAssertFalse(feedback.consume(target: true, succeeded: true))
        feedback.recordKey(previous: false, target: false)
        XCTAssertFalse(feedback.consume(target: false, succeeded: true))
        for target in [true, false] {
            feedback.recordKey(previous: !target, target: target)
            feedback.recordKey(previous: target, target: target) // duplicate event monitor
            XCTAssertFalse(feedback.consume(target: !target, succeeded: true))
            XCTAssertTrue(feedback.consume(target: target, succeeded: true))
            XCTAssertFalse(feedback.consume(target: target, succeeded: true))
        }
    }

    func testFailureIsNotSuccessAndRetryReportsRecoveryOnce() {
        var feedback = CapsLockFeedbackState()
        feedback.recordKey(previous: false, target: true)
        XCTAssertTrue(feedback.consume(target: true, succeeded: false))
        XCTAssertEqual(feedback.pending, true)
        XCTAssertFalse(feedback.consume(target: true, succeeded: false))
        feedback.recordKey(previous: true, target: true)
        XCTAssertFalse(feedback.consume(target: true, succeeded: false))
        XCTAssertTrue(feedback.consume(target: true, succeeded: true))
        XCTAssertNil(feedback.pending)
    }

    func testNewKeyOrOtherCommandSupersedesPendingFeedback() {
        var feedback = CapsLockFeedbackState()
        feedback.recordKey(previous: false, target: true)
        feedback.recordKey(previous: true, target: false)
        XCTAssertFalse(feedback.consume(target: true, succeeded: true))
        XCTAssertTrue(feedback.consume(target: false, succeeded: true))
        feedback.recordKey(previous: false, target: true)
        feedback.cancel()
        XCTAssertFalse(feedback.consume(target: true, succeeded: true))
        XCTAssertFalse(feedback.consume(target: true, succeeded: false))
    }
}

@MainActor
final class CapsLockFeedbackUITests: XCTestCase {
    func testAllLanguagesFitAndCannotTakeFocusOrMouseInput() throws {
        _ = NSApplication.shared
        for language in AppLanguage.allCases {
            for (target, succeeded, name) in [(true, true, "on"), (false, true, "off"), (true, false, "failed")] {
                let notice = CapsLockFeedbackNotice(target: target, succeeded: succeeded, at: Date(), language: language)
                let panel = try XCTUnwrap(notice.window)
                defer { notice.close() }
                XCTAssertFalse(panel.canBecomeKey)
                XCTAssertFalse(panel.canBecomeMain)
                XCTAssertTrue(panel.ignoresMouseEvents)
                let content = try XCTUnwrap(panel.contentView)
                content.layoutSubtreeIfNeeded()
                let stack = try XCTUnwrap(content.subviews.first as? NSStackView)
                let labels = stack.arrangedSubviews.compactMap { $0 as? NSTextField }
                XCTAssertEqual(labels.count, 4)
                XCTAssertEqual(labels.first?.stringValue, "Capsomnia · Caps Lock")
                for label in labels {
                    XCTAssertTrue(content.bounds.contains(label.convert(label.bounds, to: content)))
                    XCTAssertGreaterThanOrEqual(label.frame.height + 1, label.fittingSize.height)
                }
                if language == .simplifiedChinese,
                   let path = ProcessInfo.processInfo.environment["CAPSOMNIA_UI_CAPTURE_DIR"] {
                    let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
                    content.cacheDisplay(in: content.bounds, to: bitmap)
                    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try data.write(to: URL(fileURLWithPath: path).appendingPathComponent("caps-lock-\(name).png"))
                }
            }
        }
    }

    func testNoticeAutomaticallyDismissesWithoutChangingKeyWindow() async throws {
        _ = NSApplication.shared
        let key = NSApp.keyWindow
        let notice = CapsLockFeedbackNotice(target: false, succeeded: true, at: Date())
        defer { notice.close() }
        notice.present(duration: 0.05)
        XCTAssertTrue(notice.window?.isVisible == true)
        XCTAssertTrue(NSApp.keyWindow === key)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertFalse(notice.window?.isVisible ?? true)
        XCTAssertTrue(NSApp.keyWindow === key)
    }
}

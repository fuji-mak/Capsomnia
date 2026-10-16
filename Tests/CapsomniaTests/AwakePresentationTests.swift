import AppKit
import XCTest
@testable import Capsomnia

final class AwakePresentationTests: XCTestCase {
    func testOnlyConfirmedMatchingStateCanBeOnOrOff() {
        XCTAssertEqual(AwakePhase.resolve(requested: true, confirmed: false, pending: nil, failed: false), .starting)
        XCTAssertEqual(AwakePhase.resolve(requested: false, confirmed: true, pending: nil, failed: false), .stopping)
        XCTAssertEqual(AwakePhase.resolve(requested: true, confirmed: true, pending: nil, failed: false), .on)
        XCTAssertEqual(AwakePhase.resolve(requested: false, confirmed: false, pending: nil, failed: false), .off)
        XCTAssertEqual(AwakePhase.resolve(requested: nil, confirmed: true, pending: nil, failed: false), .unknown)
        XCTAssertEqual(AwakePhase.resolve(requested: true, confirmed: nil, pending: nil, failed: false), .unknown)
        XCTAssertEqual(AwakePhase.resolve(requested: false, confirmed: true, pending: nil, failed: true), .failed)
        XCTAssertEqual(AwakePhase.resolve(requested: false, confirmed: false, pending: true, failed: true), .starting)
    }

    func testPreferenceDoesNotClaimAnActiveDesktopAndFailureRetainsLastConfirmedSwitch() {
        let t = AwakeText(language: .simplifiedChinese)
        var state = AwakePresentation(computerUse: true)
        XCTAssertEqual(state.computerStatus(t), t.waitForMaster)
        XCTAssertEqual(state.summary(t), t.offSummary)
        state.phase = .on
        state.confirmedOn = true
        XCTAssertEqual(state.summary(t), t.displayUnavailable)
        state.displayActive = true
        XCTAssertEqual(state.summary(t), t.screenSummary)
        state.computerUse = false
        XCTAssertEqual(state.summary(t), t.backgroundSummary)
        state.phase = .stopping
        XCTAssertFalse(state.canToggle)
        XCTAssertTrue(state.confirmedOn)
        state.phase = .failed
        XCTAssertTrue(state.confirmedOn, "Failure must not claim that a previous on-state was turned off")
        XCTAssertEqual(state.summary(t), t.failedSummary)
        XCTAssertTrue(state.canToggle, "Allow retry")
    }
}

@MainActor
final class AwakeSettingsUITests: XCTestCase {
    private func views<T: NSView>(_ parent: NSView, visible: Bool = true) -> [T] {
        parent.subviews.flatMap { child -> [T] in
            if visible && child.isHidden { return [] }
            return ((child as? T).map { [$0] } ?? []) + views(child, visible: visible)
        }
    }

    func testMenuAndWindowUseTheSameLabelsAndConfirmedStates() {
        let master = NSMenuItem(), status = NSMenuItem(), computer = NSMenuItem()
        let computerStatus = NSMenuItem()
        for language in AppLanguage.allCases {
            let t = AwakeText(language: language)
            for phase in [AwakePhase.off, .on, .starting, .stopping, .failed, .unknown] {
                for enabled in [false, true] {
                    let state = AwakePresentation(phase: phase, confirmedOn: phase == .on || phase == .stopping,
                                                  computerUse: enabled, displayActive: phase == .on)
                    state.updateMenu(master: master, status: status, computer: computer,
                                     computerStatus: computerStatus, text: t)
                    XCTAssertEqual(master.title, t.title)
                    XCTAssertEqual(master.state, state.confirmedOn ? .on : .off)
                    XCTAssertEqual(master.isEnabled, state.canToggle)
                    XCTAssertEqual(status.title, state.status(t))
                    XCTAssertEqual(computer.title, AppStrings.localized(for: language).keepDisplayAwake)
                    XCTAssertEqual(computer.state, enabled ? .on : .off)
                    XCTAssertEqual(computerStatus.title, state.computerStatus(t))
                    XCTAssertFalse(status.isEnabled)
                }
            }
        }
    }

    func testSharedSnapshotUpdatesControlsAndGeometryAcrossAllLanguagesAndPhases() throws {
        _ = NSApplication.shared
        let language = Preferences.language
        let computer = Preferences.keepDisplayAwake
        defer {
            Preferences.language = language
            Preferences.keepDisplayAwake = computer
        }
        Preferences.keepDisplayAwake = true
        var state = AwakePresentation(computerUse: true)
        var requests: [Bool] = []
        let controller = SettingsWindowController(
            onDedicatedCapsLockModeChange: { _ in }, onShowMenuBarIconChange: { _ in },
            onLanguageChange: { _ in }, onLaunchAtLoginChange: { _ in },
            onKeepDisplayAwakeChange: { value in Preferences.keepDisplayAwake = value; state.computerUse = value },
            onKeepHotspotAliveChange: { _ in }, onIgnoreExternalCapsLockOffWhileLidClosedChange: { _ in },
            onHideCapsLockIndicatorChange: { _ in }, capsLockIndicatorStateProvider: { .init(hidden: false, restartPending: false) },
            onAutoOffMinutesChange: { _ in }, onAutoOffRestart: {}, autoOffDisplayProvider: { .idle(minutes: 0) },
            onKeyboardShortcutChange: { _ in true }, onKeyboardShortcutRecordingChange: { _ in }, onAutomaticUpdateChecksChange: { _ in }, onFinishInitialSetup: {},
            onAwakeChange: { target in requests.append(target); state.phase = target ? .starting : .stopping },
            awakePresentationProvider: { state })
        defer { controller.close() }
        for language in AppLanguage.allCases {
            Preferences.language = language
            controller.show(page: .settings)
            let content = try XCTUnwrap(controller.window?.contentView)
            let t = AwakeText.current
            let master: LEDToggle = try XCTUnwrap(views(content).first { (v: LEDToggle) in v.accessibilityLabel() == t.title })
            var stableSize: NSSize?
            for phase in [AwakePhase.off, .starting, .on, .stopping, .failed, .unknown] {
                state.phase = phase
                state.confirmedOn = phase == .on || phase == .stopping || phase == .failed
                state.displayActive = state.confirmedOn
                controller.refreshAwakePresentation()
                content.layoutSubtreeIfNeeded()
                XCTAssertEqual(master.isOn, state.confirmedOn)
                XCTAssertEqual(master.isEnabled, state.canToggle)
                let labels: [NSTextField] = views(content)
                XCTAssertTrue(labels.contains { $0.stringValue == state.status(t) })
                XCTAssertTrue(labels.contains { $0.stringValue == state.computerStatus(t) })
                XCTAssertTrue(labels.contains { $0.stringValue == state.summary(t) })
                if let stableSize { XCTAssertEqual(content.bounds.size, stableSize, "Feedback must not shift layout") }
                stableSize = content.bounds.size
                for label in labels where !label.stringValue.isEmpty {
                    XCTAssertTrue(content.bounds.insetBy(dx: -1, dy: -1).contains(label.convert(label.bounds, to: content)), label.stringValue)
                }
                if language == .simplifiedChinese || phase == .on {
                    try capture(content, name: "awake-\(language.rawValue)-\(phase)")
                }
            }
            state.phase = .off; state.confirmedOn = false; controller.refreshAwakePresentation()
            let before = requests.count
            XCTAssertTrue(master.accessibilityPerformPress())
            XCTAssertEqual(requests.count, before + 1)
            XCTAssertEqual(requests.last, true)
            XCTAssertFalse(master.accessibilityPerformPress(), "Pending blocks repeated requests")
            let computerToggle: LEDToggle = try XCTUnwrap(views(content).first { (v: LEDToggle) in v.accessibilityLabel() == AppStrings.current().keepDisplayAwake })
            XCTAssertTrue(computerToggle.accessibilityPerformPress())
            XCTAssertFalse(state.computerUse)
            XCTAssertTrue(computerToggle.accessibilityPerformPress())
        }
    }

    private func capture(_ view: NSView, name: String) throws {
        guard let dir = ProcessInfo.processInfo.environment["CAPSOMNIA_UI_CAPTURE_DIR"] else { return }
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }
}

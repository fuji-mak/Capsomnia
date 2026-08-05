import XCTest
@testable import Capsomnia

final class AutoOffPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: Disabled

    func testDisabledTimerClearsStateAndNeverFires() {
        let onResult = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 0,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(deadline: now.addingTimeInterval(-1))
        )
        XCTAssertEqual(onResult.state, AutoOffState())
        XCTAssertFalse(onResult.shouldFire)
    }

    // MARK: Arming / counting (awake on)

    func testArmsFullDurationOnFirstStart() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 30,
            restartOnReenable: false,
            now: now,
            state: AutoOffState()
        )
        XCTAssertEqual(result.state.deadline, now.addingTimeInterval(30 * 60))
        XCTAssertNil(result.state.pausedRemaining)
        XCTAssertFalse(result.shouldFire)
    }

    func testKeepsExistingDeadlineWhileCountingDown() {
        let deadline = now.addingTimeInterval(5 * 60)
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 30,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(deadline: deadline)
        )
        XCTAssertEqual(result.state.deadline, deadline)
        XCTAssertFalse(result.shouldFire)
    }

    func testFiresWhenDeadlineReached() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 30,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(deadline: now)
        )
        XCTAssertEqual(result.state, AutoOffState())
        XCTAssertTrue(result.shouldFire)
    }

    // MARK: Pause / resume (preserve mode)

    func testPausesRemainingWhenAwakeTurnsOff() {
        let deadline = now.addingTimeInterval(40 * 60)
        let result = AutoOffPolicy.evaluate(
            capsLockOn: false,
            autoOffMinutes: 60,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(deadline: deadline)
        )
        XCTAssertNil(result.state.deadline)
        XCTAssertEqual(result.state.pausedRemaining, 40 * 60)
        XCTAssertFalse(result.shouldFire)
    }

    func testResumesFromPausedRemainingInsteadOfRestarting() {
        // Awake mode comes back on with 40 minutes banked from before.
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 60,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(pausedRemaining: 40 * 60)
        )
        XCTAssertEqual(result.state.deadline, now.addingTimeInterval(40 * 60))
        XCTAssertNil(result.state.pausedRemaining)
        XCTAssertFalse(result.shouldFire)
    }

    func testKeepsPausedRemainingWhileStillOff() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: false,
            autoOffMinutes: 60,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(pausedRemaining: 40 * 60)
        )
        XCTAssertNil(result.state.deadline)
        XCTAssertEqual(result.state.pausedRemaining, 40 * 60)
    }

    func testResumingWithNoTimeLeftFires() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 60,
            restartOnReenable: false,
            now: now,
            state: AutoOffState(pausedRemaining: 0)
        )
        XCTAssertEqual(result.state, AutoOffState())
        XCTAssertTrue(result.shouldFire)
    }

    // MARK: Restart-on-reenable mode (old behavior)

    func testRestartModeForgetsRemainingWhenOff() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: false,
            autoOffMinutes: 60,
            restartOnReenable: true,
            now: now,
            state: AutoOffState(deadline: now.addingTimeInterval(40 * 60))
        )
        XCTAssertEqual(result.state, AutoOffState())
    }

    func testRestartModeArmsFullDurationOnReenable() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 60,
            restartOnReenable: true,
            now: now,
            state: AutoOffState(pausedRemaining: 40 * 60)
        )
        XCTAssertEqual(result.state.deadline, now.addingTimeInterval(60 * 60))
        XCTAssertFalse(result.shouldFire)
    }

    // MARK: Explicit restart

    func testRestartedArmsFullDurationWhenAwake() {
        let state = AutoOffPolicy.restarted(capsLockOn: true, autoOffMinutes: 120, now: now)
        XCTAssertEqual(state.deadline, now.addingTimeInterval(120 * 60))
        XCTAssertNil(state.pausedRemaining)
    }

    func testRestartedBanksFullDurationWhenOff() {
        let state = AutoOffPolicy.restarted(capsLockOn: false, autoOffMinutes: 120, now: now)
        XCTAssertNil(state.deadline)
        XCTAssertEqual(state.pausedRemaining, 120 * 60)
    }

    func testRestartedIsEmptyWhenTimerDisabled() {
        XCTAssertEqual(
            AutoOffPolicy.restarted(capsLockOn: true, autoOffMinutes: 0, now: now),
            AutoOffState()
        )
    }
}

final class AutoOffFormatterTests: XCTestCase {
    func testCountdownFormatsHoursMinutesSeconds() {
        XCTAssertEqual(AutoOffFormatter.countdown(0), "00:00:00")
        XCTAssertEqual(AutoOffFormatter.countdown(59), "00:00:59")
        XCTAssertEqual(AutoOffFormatter.countdown(3661), "01:01:01")
        XCTAssertEqual(AutoOffFormatter.countdown(7200), "02:00:00")
    }

    func testCountdownClampsNegativeToZero() {
        XCTAssertEqual(AutoOffFormatter.countdown(-42), "00:00:00")
    }

    func testMenuBarIsCompactAndDropsLeadingZeroHour() {
        XCTAssertEqual(AutoOffFormatter.menuBar(9), "0:09")
        XCTAssertEqual(AutoOffFormatter.menuBar(59 * 60 + 5), "59:05")
        XCTAssertEqual(AutoOffFormatter.menuBar(3600 + 2 * 60 + 5), "1:02:05")
        XCTAssertEqual(AutoOffFormatter.menuBar(-10), "0:00")
    }

    func testDurationLabelIsCompactAndLanguageNeutral() {
        XCTAssertEqual(AutoOffFormatter.durationLabel(minutes: 0), "∞")
        XCTAssertEqual(AutoOffFormatter.durationLabel(minutes: 15), "15m")
        XCTAssertEqual(AutoOffFormatter.durationLabel(minutes: 60), "1h")
        XCTAssertEqual(AutoOffFormatter.durationLabel(minutes: 90), "1h 30m")
        XCTAssertEqual(AutoOffFormatter.durationLabel(minutes: 120), "2h")
        XCTAssertEqual(AutoOffFormatter.durationLabel(minutes: 480), "8h")
    }
}

final class AutoOffPresetTests: XCTestCase {
    func testQuickPickRecognizesPresetsOnly() {
        XCTAssertTrue(AutoOffPreset.isQuickPick(60))
        XCTAssertTrue(AutoOffPreset.isQuickPick(480))
        XCTAssertFalse(AutoOffPreset.isQuickPick(45))
        XCTAssertFalse(AutoOffPreset.isQuickPick(0))
    }

    func testCustomBoundsAreSane() {
        XCTAssertEqual(AutoOffPreset.minCustomMinutes, 1)
        XCTAssertEqual(AutoOffPreset.maxCustomMinutes, 24 * 60)
        XCTAssertEqual(AutoOffPreset.minuteOptions, [15, 30, 60, 120, 240, 480])
    }
}

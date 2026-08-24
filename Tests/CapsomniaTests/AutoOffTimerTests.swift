import XCTest
@testable import Capsomnia

final class AutoOffPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: Disabled

    func testDisabledTimerClearsStateAndNeverFires() {
        let onResult = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 0,
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
            now: now,
            state: AutoOffState()
        )
        XCTAssertEqual(result.state.deadline, now.addingTimeInterval(30 * 60))
        XCTAssertFalse(result.shouldFire)
    }

    func testKeepsExistingDeadlineWhileCountingDown() {
        let deadline = now.addingTimeInterval(5 * 60)
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 30,
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
            now: now,
            state: AutoOffState(deadline: now)
        )
        XCTAssertEqual(result.state, AutoOffState())
        XCTAssertTrue(result.shouldFire)
    }

    // MARK: Re-enable behavior

    func testTurningOffClearsTheCurrentCountdown() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: false,
            autoOffMinutes: 60,
            now: now,
            state: AutoOffState(deadline: now.addingTimeInterval(40 * 60))
        )
        XCTAssertEqual(result.state, AutoOffState())
        XCTAssertFalse(result.shouldFire)
    }

    func testReenableAlwaysStartsTheFullDuration() {
        let result = AutoOffPolicy.evaluate(
            capsLockOn: true,
            autoOffMinutes: 60,
            now: now,
            state: AutoOffState()
        )
        XCTAssertEqual(result.state.deadline, now.addingTimeInterval(60 * 60))
        XCTAssertFalse(result.shouldFire)
    }

    // MARK: Explicit restart

    func testRestartedArmsFullDurationWhenAwake() {
        let state = AutoOffPolicy.restarted(capsLockOn: true, autoOffMinutes: 120, now: now)
        XCTAssertEqual(state.deadline, now.addingTimeInterval(120 * 60))
    }

    func testRestartedWhileOffLeavesTheNextEnableFresh() {
        let state = AutoOffPolicy.restarted(capsLockOn: false, autoOffMinutes: 120, now: now)
        XCTAssertEqual(state, AutoOffState())
    }

    func testRestartedIsEmptyWhenTimerDisabled() {
        XCTAssertEqual(
            AutoOffPolicy.restarted(capsLockOn: true, autoOffMinutes: 0, now: now),
            AutoOffState()
        )
    }
}

final class AutoOffSleepCoordinatorTests: XCTestCase {
    func testSuccessfulAutoOffSleepsOnceAfterConfirmedOff() {
        var sleepRequestCount = 0
        let coordinator = AutoOffSleepCoordinator {
            sleepRequestCount += 1
            return (0, "", "")
        }

        coordinator.recordCapsLockResult(.changed(to: false))

        XCTAssertTrue(coordinator.isPending)
        XCTAssertEqual(
            coordinator.requestSleepIfReady(capsLockOn: false)?.status,
            0
        )
        XCTAssertFalse(coordinator.isPending)
        XCTAssertEqual(sleepRequestCount, 1)
        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false))
        XCTAssertEqual(sleepRequestCount, 1)
    }

    func testFailedCapsLockOffNeverSleeps() {
        var sleepRequestCount = 0
        let coordinator = AutoOffSleepCoordinator {
            sleepRequestCount += 1
            return (0, "", "")
        }

        coordinator.recordCapsLockResult(.writeFailed(target: false))

        XCTAssertFalse(coordinator.isPending)
        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false))
        XCTAssertEqual(sleepRequestCount, 0)
    }

    func testConfirmedOnCancelsPendingSleep() {
        var sleepRequestCount = 0
        let coordinator = AutoOffSleepCoordinator {
            sleepRequestCount += 1
            return (0, "", "")
        }

        coordinator.recordCapsLockResult(.changed(to: false))

        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: true))
        XCTAssertFalse(coordinator.isPending)
        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false))
        XCTAssertEqual(sleepRequestCount, 0)
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
        XCTAssertEqual(AutoOffPreset.customHourStep, 60)
        XCTAssertEqual(AutoOffPreset.customMinuteStep, 1)
        XCTAssertEqual(AutoOffPreset.minuteOptions, [15, 30, 60, 120, 240, 480])
    }

    func testCustomMinuteAdjustmentUsesOneMinuteStepsAndClamps() {
        XCTAssertEqual(AutoOffPreset.adjustedCustomMinutes(45, by: 1), 46)
        XCTAssertEqual(AutoOffPreset.adjustedCustomMinutes(45, by: -1), 44)
        XCTAssertEqual(AutoOffPreset.adjustedCustomMinutes(1, by: -1), 1)
        XCTAssertEqual(AutoOffPreset.adjustedCustomMinutes(24 * 60, by: 1), 24 * 60)
    }
}

final class AutoOffMenuFormatterTests: XCTestCase {
    func testCountingTitleIncludesLocalizedPrefixAndCountdown() {
        XCTAssertEqual(
            AutoOffMenuFormatter.title(
                base: "自動オフタイマー",
                turnsOffIn: "オフまで",
                state: .counting(remaining: 3661)
            ),
            "自動オフタイマー (オフまで 01:01:01)"
        )
    }

    func testInactiveTitlesStayCompact() {
        XCTAssertEqual(
            AutoOffMenuFormatter.title(
                base: "Auto-off timer",
                turnsOffIn: "Turns off in",
                state: .idle(minutes: 60)
            ),
            "Auto-off timer"
        )
        XCTAssertEqual(
            AutoOffMenuFormatter.title(
                base: "Auto-off timer",
                turnsOffIn: "Turns off in",
                state: .infinite
            ),
            "Auto-off timer"
        )
    }

    func testCustomTitleShowsOnlyNonPresetDuration() {
        XCTAssertEqual(
            AutoOffMenuFormatter.customTitle(base: "Custom", selectedMinutes: 45),
            "Custom (45m)"
        )
        XCTAssertEqual(
            AutoOffMenuFormatter.customTitle(base: "Custom", selectedMinutes: 60),
            "Custom"
        )
        XCTAssertEqual(
            AutoOffMenuFormatter.customTitle(base: "Custom", selectedMinutes: 0),
            "Custom"
        )
    }
}

final class AutoOffMenuSelectionPolicyTests: XCTestCase {
    func testReselectingCurrentDurationDoesNotRestartTimer() {
        XCTAssertFalse(
            AutoOffMenuSelectionPolicy.shouldApply(
                currentMinutes: 60,
                selectedMinutes: 60
            )
        )
    }

    func testSelectingDifferentDurationAppliesChange() {
        XCTAssertTrue(
            AutoOffMenuSelectionPolicy.shouldApply(
                currentMinutes: 60,
                selectedMinutes: 120
            )
        )
    }
}

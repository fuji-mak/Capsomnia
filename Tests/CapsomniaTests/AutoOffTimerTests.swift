import XCTest
@testable import Capsomnia

final class SessionAutoOffTimerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testDisabledDefaultClearsCountdownWithoutFiring() {
        var timer = SessionAutoOffTimer()
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 30, now: now))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(30 * 60))

        XCTAssertFalse(timer.evaluate(
            capsLockOn: true, defaultMinutes: 0, now: now.addingTimeInterval(30 * 60)
        ))
        XCTAssertNil(timer.deadline)
    }

    func testSavedTimerKeepsDeadlineAndFiresOnlyOnce() {
        var timer = SessionAutoOffTimer()
        let deadline = now.addingTimeInterval(30 * 60)
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 30, now: now))
        XCTAssertEqual(timer.deadline, deadline)

        XCTAssertFalse(timer.evaluate(
            capsLockOn: true, defaultMinutes: 60, now: deadline.addingTimeInterval(-1)
        ))
        XCTAssertEqual(timer.deadline, deadline)
        XCTAssertTrue(timer.evaluate(capsLockOn: true, defaultMinutes: 60, now: deadline))
        XCTAssertNil(timer.deadline)
        XCTAssertFalse(timer.evaluate(
            capsLockOn: true, defaultMinutes: 60, now: deadline.addingTimeInterval(1)
        ))
        XCTAssertNil(timer.deadline)
    }

    func testTurningOffClearsCountdownAndNextEnableStartsFullDuration() {
        var timer = SessionAutoOffTimer()
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 60, now: now))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(60 * 60))

        XCTAssertFalse(timer.evaluate(
            capsLockOn: false, defaultMinutes: 60, now: now.addingTimeInterval(20 * 60)
        ))
        XCTAssertNil(timer.deadline)

        let nextEnable = now.addingTimeInterval(30 * 60)
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 60, now: nextEnable))
        XCTAssertEqual(timer.deadline, nextEnable.addingTimeInterval(60 * 60))
    }

    func testOneShotReplacesDefaultAndRestoresItNextSession() {
        var timer = SessionAutoOffTimer()
        timer.set(seconds: 90, now: now)
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 120, now: now))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(90))
        XCTAssertTrue(timer.evaluate(capsLockOn: true, defaultMinutes: 120, now: now.addingTimeInterval(90)))
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 120, now: now.addingTimeInterval(91)))
        XCTAssertFalse(timer.evaluate(capsLockOn: false, defaultMinutes: 120, now: now))
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 120, now: now))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(7200))
        XCTAssertEqual(timer.source, "settings")
    }

    func testCancelSuppressesDefaultOnlyForCurrentSession() {
        var timer = SessionAutoOffTimer()
        timer.set(seconds: 120, now: now)
        timer.cancel()
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 1, now: now.addingTimeInterval(3600)))
        XCTAssertNil(timer.deadline)
        XCTAssertEqual(timer.source, "cancelled")
        XCTAssertFalse(timer.evaluate(capsLockOn: false, defaultMinutes: 1, now: now))
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 1, now: now))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(60))
    }

    func testReplacementRestartAndSavedSettingChange() {
        var timer = SessionAutoOffTimer()
        timer.set(seconds: 7200, now: now)
        timer.set(seconds: 60, now: now.addingTimeInterval(5))
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 480, now: now.addingTimeInterval(6)))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(65))
        timer.restart(capsLockOn: true, defaultMinutes: 480, now: now.addingTimeInterval(30))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(90))
    }
}

final class AutoOffSleepCoordinatorTests: XCTestCase {
    func testTimerExpiryWithOpenOrUnknownLidNeverSleepsEvenAfterLaterClosure() {
        for lidClosed in [false, nil] as [Bool?] {
            var timer = SessionAutoOffTimer()
            let now = Date(timeIntervalSince1970: 1_000_000)
            timer.set(seconds: 60, now: now)
            var sleepRequests = 0
            let coordinator = AutoOffSleepCoordinator {
                sleepRequests += 1
                return (0, "", "")
            }

            XCTAssertTrue(timer.evaluate(capsLockOn: true, defaultMinutes: 0, now: now.addingTimeInterval(60)))
            coordinator.recordCapsLockResult(.changed(to: false))
            XCTAssertEqual(sleepRequests, 0, "OFF must be confirmed before deciding whether to sleep")
            XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false, clamshellClosed: lidClosed))
            XCTAssertFalse(coordinator.isPending)
            XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false, clamshellClosed: true))
            XCTAssertEqual(sleepRequests, 0, "Opening the lid cancels sleep rather than postponing it")
        }
    }

    func testSuccessfulAutoOffSleepsOnceAfterConfirmedOff() {
        var sleepRequestCount = 0
        let coordinator = AutoOffSleepCoordinator {
            sleepRequestCount += 1
            return (0, "", "")
        }

        coordinator.recordCapsLockResult(.changed(to: false))

        XCTAssertTrue(coordinator.isPending)
        XCTAssertEqual(
            coordinator.requestSleepIfReady(capsLockOn: false, clamshellClosed: true)?.status,
            0
        )
        XCTAssertFalse(coordinator.isPending)
        XCTAssertEqual(sleepRequestCount, 1)
        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false, clamshellClosed: true))
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
        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false, clamshellClosed: true))
        XCTAssertEqual(sleepRequestCount, 0)
    }

    func testConfirmedOnCancelsPendingSleep() {
        var sleepRequestCount = 0
        let coordinator = AutoOffSleepCoordinator {
            sleepRequestCount += 1
            return (0, "", "")
        }

        coordinator.recordCapsLockResult(.changed(to: false))

        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: true, clamshellClosed: true))
        XCTAssertFalse(coordinator.isPending)
        XCTAssertNil(coordinator.requestSleepIfReady(capsLockOn: false, clamshellClosed: true))
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

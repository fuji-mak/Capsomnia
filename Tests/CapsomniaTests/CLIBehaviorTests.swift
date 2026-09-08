import Foundation
import XCTest
@testable import Capsomnia

final class CLIBehaviorTests: XCTestCase {
    func testOneShotReplacesDefaultAndRestoresItNextSession() {
        let now = Date(timeIntervalSince1970: 1000)
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
        let now = Date()
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
        let now = Date()
        var timer = SessionAutoOffTimer()
        timer.set(seconds: 7200, now: now)
        timer.set(seconds: 60, now: now.addingTimeInterval(5))
        XCTAssertFalse(timer.evaluate(capsLockOn: true, defaultMinutes: 480, now: now.addingTimeInterval(6)))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(65))
        timer.restart(capsLockOn: true, defaultMinutes: 480, now: now.addingTimeInterval(30))
        XCTAssertEqual(timer.deadline, now.addingTimeInterval(90))
    }

    func testOffConfirmsHardwareAndSleepPreventionBeforeSleeping() {
        var steps: [String] = []
        ExplicitAwakeCommand.run(
            target: false,
            setCapsLock: { target, done in steps.append("caps-off"); done(.changed(to: target)) },
            synchronize: { _ in steps.append("helper-confirmed"); return true },
            readCapsLock: { steps.append("caps-confirmed"); return false },
            sleep: { steps.append("sleep"); return (0, "", "") },
            completion: { result in XCTAssertEqual(try? result.get(), true); steps.append("reply") }
        )
        XCTAssertEqual(steps, ["caps-off", "helper-confirmed", "caps-confirmed", "sleep", "reply"])
    }

    func testOffNeverSleepsIfStateUnconfirmedOrChangedBackOn() {
        for synchronized in [false, true] {
            var slept = false
            ExplicitAwakeCommand.run(
                target: false,
                setCapsLock: { _, done in done(.changed(to: false)) },
                synchronize: { _ in synchronized },
                readCapsLock: { true },
                sleep: { slept = true; return (0, "", "") },
                completion: { result in
                    if case .success = result { XCTFail("Unconfirmed OFF must fail") }
                }
            )
            XCTAssertFalse(slept)
        }
    }

    func testHardwareAndSleepRequestFailuresAreReported() {
        ExplicitAwakeCommand.run(
            target: false,
            setCapsLock: { _, done in done(.unavailable) },
            synchronize: { _ in XCTFail("Do not sync after failed hardware write"); return true },
            readCapsLock: { false },
            sleep: { XCTFail("Do not sleep after failed write"); return (0, "", "") },
            completion: { result in if case .success = result { XCTFail("Expected failure") } }
        )
        ExplicitAwakeCommand.run(
            target: false,
            setCapsLock: { _, done in done(.changed(to: false)) },
            synchronize: { _ in true }, readCapsLock: { false },
            sleep: { (1, "", "denied") },
            completion: { result in if case .success = result { XCTFail("Expected sleep failure") } }
        )
    }

    func testOnDoesNotSleep() {
        ExplicitAwakeCommand.run(
            target: true,
            setCapsLock: { _, done in done(.changed(to: true)) },
            synchronize: { _ in true }, readCapsLock: { true },
            sleep: { XCTFail("ON must not sleep"); return (0, "", "") },
            completion: { result in XCTAssertEqual(try? result.get(), false) }
        )
    }

    func testDurationBoundsAndNonFiniteValues() {
        XCTAssertEqual(ControlInput.duration("2h"), 7200)
        XCTAssertEqual(ControlInput.duration("90s"), 90)
        for invalid in ["0s", "-1m", "25h", "nans", "infs", "10", "1d"] {
            XCTAssertNil(ControlInput.duration(invalid), invalid)
        }
    }
}

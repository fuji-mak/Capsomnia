import XCTest
@testable import Capsomnia

final class CapsLockStateWriterTests: XCTestCase {
    /// Models Apple's keyboard filter: writing the cached value is a no-op.
    /// The global modifier flags can nevertheless have been cleared elsewhere.
    private final class Keyboard {
        var cached: Bool
        var observed: Bool?
        var writes: [Bool] = []
        var ignoreAllWrites = false
        var failWriteAt: Int?

        init(cached: Bool, observed: Bool?) {
            self.cached = cached
            self.observed = observed
        }
        func write(_ value: Bool) -> Bool {
            writes.append(value)
            if writes.count == failWriteAt { return false }
            if cached != value && !ignoreAllWrites {
                cached = value
                observed = value
            }
            return true
        }
        var writer: CapsLockStateWriter {
            CapsLockStateWriter(writeState: write, confirmation: .init(
                readState: { self.observed }, wait: {},
                maximumAttempts: 5, requiredConsecutiveMatches: 3))
        }
    }

    func testReconcilesStaleKeyboardCacheForOnAndOff() {
        for target in [true, false] {
            let keyboard = Keyboard(cached: target, observed: !target)
            XCTAssertEqual(keyboard.writer.set(target), .changed(to: target))
            XCTAssertEqual(keyboard.writes, [target, !target, target])
            XCTAssertEqual(keyboard.observed, target)
            XCTAssertEqual(keyboard.cached, target)
        }
    }

    func testNormalAndAlreadyMatchingWritesDoNotResetTheKeyboard() {
        for target in [true, false] {
            for initial in [true, false] {
                let keyboard = Keyboard(cached: initial, observed: initial)
                XCTAssertEqual(keyboard.writer.set(target), .changed(to: target))
                XCTAssertEqual(keyboard.writes, [target])
            }
        }
    }

    func testUnavailableReadDoesNotGuessARecoveryState() {
        let keyboard = Keyboard(cached: true, observed: nil)
        XCTAssertEqual(keyboard.writer.set(true), .verificationFailed(target: true, actual: nil))
        XCTAssertEqual(keyboard.writes, [true])
    }

    func testPersistentMismatchStopsAfterOneReconciliation() {
        let keyboard = Keyboard(cached: true, observed: false)
        keyboard.ignoreAllWrites = true
        XCTAssertEqual(keyboard.writer.set(true), .verificationFailed(target: true, actual: false))
        XCTAssertEqual(keyboard.writes, [true, false, true])
    }

    func testWriteErrorsAtEachStageStopWithoutClaimingSuccess() {
        for failingWrite in 1...3 {
            let keyboard = Keyboard(cached: true, observed: false)
            keyboard.failWriteAt = failingWrite
            XCTAssertEqual(keyboard.writer.set(true), .writeFailed(target: true))
            XCTAssertEqual(keyboard.writes.count, failingWrite)
        }
    }

    func testDelayedSuccessDoesNotGetResetByRecovery() {
        var states: [Bool?] = [false, false, false, true, true, true]
        var writes: [Bool] = []
        let writer = CapsLockStateWriter(writeState: { writes.append($0); return true },
            confirmation: .init(readState: { states.removeFirst() }, wait: {},
                                maximumAttempts: 3, requiredConsecutiveMatches: 3))
        XCTAssertEqual(writer.set(true), .changed(to: true))
        XCTAssertEqual(writes, [true])
    }

    func testReadLossDuringRecheckDoesNotResetKeyboard() {
        var states: [Bool?] = [false, false, false, nil, nil, nil]
        var writes: [Bool] = []
        let writer = CapsLockStateWriter(writeState: { writes.append($0); return true },
            confirmation: .init(readState: { states.removeFirst() }, wait: {},
                                maximumAttempts: 3, requiredConsecutiveMatches: 3))
        XCTAssertEqual(writer.set(true), .verificationFailed(target: true, actual: nil))
        XCTAssertEqual(writes, [true])
    }

    func testUnstableTargetIsNotSuccessAndDoesNotCauseReset() {
        var states: [Bool?] = [true, false, true]
        var writes: [Bool] = []
        let writer = CapsLockStateWriter(writeState: { writes.append($0); return true },
            confirmation: .init(readState: { states.removeFirst() }, wait: {},
                                maximumAttempts: 3, requiredConsecutiveMatches: 3))
        XCTAssertEqual(writer.set(true), .verificationFailed(target: true, actual: true))
        XCTAssertEqual(writes, [true])
    }

    func testUnconfirmedRecoveryBaselineStopsBeforeFinalWrite() {
        var states: [Bool?] = Array(repeating: false, count: 6) + [nil, nil, nil]
        var writes: [Bool] = []
        let writer = CapsLockStateWriter(writeState: { writes.append($0); return true },
            confirmation: .init(readState: { states.removeFirst() }, wait: {},
                                maximumAttempts: 3, requiredConsecutiveMatches: 3))
        XCTAssertEqual(writer.set(true), .verificationFailed(target: true, actual: nil))
        XCTAssertEqual(writes, [true, false])
    }
}

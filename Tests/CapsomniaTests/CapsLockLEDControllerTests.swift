import Foundation
import XCTest
@testable import Capsomnia

private final class RecordingCapsLockLEDWriter: CapsLockLEDWriting {
    private let lock = NSLock()
    private var effectiveMode: CapsLockLEDMode = .off
    private var writes: [CapsLockLEDMode] = []

    var onWrite: ((CapsLockLEDMode, Int) -> Void)?

    func setMode(_ mode: CapsLockLEDMode) throws -> CapsLockLEDUpdateResult {
        let count: Int
        lock.lock()
        effectiveMode = mode
        writes.append(mode)
        count = writes.filter { $0 == mode }.count
        lock.unlock()

        onWrite?(mode, count)
        return CapsLockLEDUpdateResult(
            matchedKeyboards: 1,
            targetedKeyboards: 1,
            successfulWrites: 1
        )
    }

    func isModeApplied(_ mode: CapsLockLEDMode) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return effectiveMode == mode
    }

    func simulateExternalWrite(_ mode: CapsLockLEDMode) {
        lock.lock()
        effectiveMode = mode
        lock.unlock()
    }

    func writeCount(for mode: CapsLockLEDMode) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return writes.filter { $0 == mode }.count
    }

    var lastWrite: CapsLockLEDMode? {
        lock.lock()
        defer { lock.unlock() }
        return writes.last
    }
}

private enum RepeatedLEDTestError: LocalizedError {
    case unavailable

    var errorDescription: String? { "test LED service unavailable" }
}

private final class AlwaysFailingCapsLockLEDWriter: CapsLockLEDWriting {
    private let lock = NSLock()
    private var storedReadCount = 0
    private var writes: [CapsLockLEDMode] = []

    var readCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedReadCount
    }

    func setMode(_ mode: CapsLockLEDMode) throws -> CapsLockLEDUpdateResult {
        guard mode == .automatic else {
            throw RepeatedLEDTestError.unavailable
        }
        lock.lock()
        writes.append(mode)
        lock.unlock()
        return CapsLockLEDUpdateResult(
            matchedKeyboards: 1,
            targetedKeyboards: 1,
            successfulWrites: 1
        )
    }

    func isModeApplied(_ mode: CapsLockLEDMode) throws -> Bool {
        lock.lock()
        storedReadCount += 1
        lock.unlock()
        throw RepeatedLEDTestError.unavailable
    }

    var lastWrite: CapsLockLEDMode? {
        lock.lock()
        defer { lock.unlock() }
        return writes.last
    }
}

final class CapsLockLEDControllerTests: XCTestCase {
    func testRepairsAnExternalOffWriteAndStopsBeforeAutomaticRestore() {
        let writer = RecordingCapsLockLEDWriter()
        let initialWrite = expectation(description: "initial on write")
        let repairWrite = expectation(description: "repair on write")
        writer.onWrite = { mode, count in
            guard mode == .on else { return }
            if count == 1 {
                initialWrite.fulfill()
            } else if count == 2 {
                repairWrite.fulfill()
            }
        }

        let controller = CapsLockLEDController(
            writer: writer,
            pollInterval: .milliseconds(1),
            pollLeeway: .nanoseconds(0)
        ) { _ in }

        controller.synchronize(enabled: true, reason: "test")
        wait(for: [initialWrite], timeout: 1)

        // This models the Off write performed by macOS after Control+Space.
        writer.simulateExternalWrite(.off)
        wait(for: [repairWrite], timeout: 1)

        controller.restoreAutomaticImmediately(reason: "test_cleanup")
        writer.simulateExternalWrite(.off)
        Thread.sleep(forTimeInterval: 0.02)

        XCTAssertEqual(writer.writeCount(for: .on), 2)
        XCTAssertEqual(writer.lastWrite, .automatic)
    }

    func testStopsPollingAfterThreeRepeatedFailures() {
        let writer = AlwaysFailingCapsLockLEDWriter()
        let stopped = expectation(description: "maintenance stopped")
        let controller = CapsLockLEDController(
            writer: writer,
            retryPolicy: CapsLockLEDRetryPolicy(baseDelay: 0.001),
            pollInterval: .milliseconds(1),
            pollLeeway: .nanoseconds(0)
        ) { message in
            if message.contains("attempts=3 action=stopped") {
                stopped.fulfill()
            }
        }

        controller.synchronize(enabled: true, reason: "test")
        wait(for: [stopped], timeout: 1)
        XCTAssertEqual(writer.readCount, 3)
        XCTAssertEqual(writer.lastWrite, .automatic)

        // Periodic confirmation of the same state must not silently restart a
        // halted failure sequence. A user state change starts a new sequence.
        controller.synchronize(enabled: true, reason: "test_repeat")
        Thread.sleep(forTimeInterval: 0.02)
        XCTAssertEqual(writer.readCount, 3)

        controller.restoreAutomaticImmediately(reason: "test_cleanup")
    }
}

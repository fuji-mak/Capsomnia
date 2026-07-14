import XCTest
import IOKit
@testable import Capsomnia

private final class AlwaysFailingCapsLockLEDWriter: CapsLockLEDWriting {
    private let lock = NSLock()
    private var storedWriteCount = 0

    var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedWriteCount
    }

    func writeCapsLockLED(enabled: Bool) -> CapsLockLEDWriteResult {
        lock.lock()
        storedWriteCount += 1
        lock.unlock()

        return CapsLockLEDWriteResult(
            matchedDevices: 1,
            matchedElements: 1,
            successfulWrites: 0,
            errorCodes: [kIOReturnNotPermitted]
        )
    }
}

final class CapsLockLEDControllerTests: XCTestCase {
    func testStopsRetryingSameFailureAfterThreeAttempts() {
        let writer = AlwaysFailingCapsLockLEDWriter()
        let stopped = expectation(description: "retry sequence stopped")
        let controller = CapsLockLEDController(
            writer: writer,
            retryPolicy: CapsLockLEDRetryPolicy(baseDelay: 0.001)
        ) { message in
            if message.contains("attempts=3 action=stopped") {
                stopped.fulfill()
            }
        }

        controller.synchronize(enabled: true, reason: "test")
        wait(for: [stopped], timeout: 1)
        XCTAssertEqual(writer.writeCount, 3)

        // A periodic confirmation of the unchanged request must not silently
        // restart a failure sequence after the bounded retry policy halted it.
        controller.synchronize(enabled: true, reason: "test_repeat")
        let settled = expectation(description: "repeat request was coalesced")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            XCTAssertEqual(writer.writeCount, 3)
            settled.fulfill()
        }
        wait(for: [settled], timeout: 1)
    }
}

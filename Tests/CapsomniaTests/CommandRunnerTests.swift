import Foundation
import XCTest
@testable import Capsomnia

final class CommandRunnerTests: XCTestCase {
    func testDrainsLargeStandardOutputAndErrorWithoutDeadlocking() {
        let byteCount = 200_000
        let script = """
        /bin/dd if=/dev/zero bs=\(byteCount) count=1 2>/dev/null | /usr/bin/tr '\\0' o
        /bin/dd if=/dev/zero bs=\(byteCount) count=1 2>/dev/null | /usr/bin/tr '\\0' e >&2
        """

        let result = CommandRunner.run("/bin/sh", ["-c", script])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout.utf8.count, byteCount)
        XCTAssertEqual(result.stderr.utf8.count, byteCount)
        XCTAssertEqual(result.stdout.first, "o")
        XCTAssertEqual(result.stdout.last, "o")
        XCTAssertEqual(result.stderr.first, "e")
        XCTAssertEqual(result.stderr.last, "e")
    }

    @MainActor
    func testWaitDoesNotRunMainRunLoopCallbacks() {
        var timerDidFire = false
        let timer = Timer(timeInterval: 0.01, repeats: false) { _ in
            timerDidFire = true
        }
        RunLoop.main.add(timer, forMode: .default)
        defer { timer.invalidate() }

        let result = CommandRunner.run("/bin/sh", ["-c", "sleep 0.1"])

        XCTAssertEqual(result.status, 0)
        XCTAssertFalse(timerDidFire)

        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertTrue(timerDidFire)
    }
}

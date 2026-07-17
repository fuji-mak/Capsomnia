import XCTest
@testable import Capsomnia

final class CapsLockLEDRetryPolicyTests: XCTestCase {
    func testUsesExponentialBackoffWithUpToFiftyPercentJitter() {
        var policy = CapsLockLEDRetryPolicy(baseDelay: 1)

        XCTAssertEqual(policy.delayAfterFailure(randomUnit: 0), 1)
        XCTAssertEqual(policy.delayAfterFailure(randomUnit: 1), 3)
    }

    func testStopsAfterThirdConsecutiveFailure() {
        var policy = CapsLockLEDRetryPolicy(baseDelay: 1)

        XCTAssertNotNil(policy.delayAfterFailure(randomUnit: 0.5))
        XCTAssertNotNil(policy.delayAfterFailure(randomUnit: 0.5))
        XCTAssertNil(policy.delayAfterFailure(randomUnit: 0.5))
        XCTAssertEqual(policy.consecutiveFailures, 3)
    }

    func testResetStartsANewFailureSequence() {
        var policy = CapsLockLEDRetryPolicy(baseDelay: 1)
        _ = policy.delayAfterFailure(randomUnit: 0.5)
        _ = policy.delayAfterFailure(randomUnit: 0.5)

        policy.reset()

        XCTAssertEqual(policy.delayAfterFailure(randomUnit: 0), 1)
        XCTAssertEqual(policy.consecutiveFailures, 1)
    }
}

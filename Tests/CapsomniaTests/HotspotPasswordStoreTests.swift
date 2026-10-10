import Security
import LocalAuthentication
import XCTest
@testable import Capsomnia

final class HotspotPasswordStoreTests: XCTestCase {
    private final class Fixture {
        var prompt = true
        var switches: [Bool] = []
        var reads = 0
        var deletes = 0
        var adds = 0
        var result: (OSStatus, Data?) = (errSecItemNotFound, nil)
        var getStatus = errSecSuccess
        var updateStatus = errSecSuccess
        var switchResults: [OSStatus] = []
        lazy var store = HotspotPasswordStore(operations: HotspotPasswordStore.Operations(
            getPrompts: { [unowned self] in (getStatus, prompt) },
            setPrompts: { [unowned self] allowed in
                switches.append(allowed)
                let status = switchResults.isEmpty ? errSecSuccess : switchResults.removeFirst()
                if status == errSecSuccess { prompt = allowed }
                return status
            },
            read: { [unowned self] query in
                XCTAssertFalse(prompt)
                XCTAssertEqual((query[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed, true)
                reads += 1
                return result
            },
            update: { [unowned self] _, _ in XCTAssertTrue(prompt); return updateStatus },
            add: { [unowned self] _ in adds += 1; return errSecSuccess },
            delete: { [unowned self] _ in deletes += 1; return errSecSuccess }
        ))
        func read(_ permit: HotspotJoinPermit = HotspotJoinPermit()) -> HotspotPasswordRead? {
            let done = XCTestExpectation(description: "read completed")
            var answer: HotspotPasswordRead?
            store.read("Fixture", permit: permit) { answer = $0; done.fulfill() }
            _ = XCTWaiter.wait(for: [done], timeout: 2)
            return answer
        }
    }

    func testReadSuppressesAndRestoresPromptsForSuccessMissingAndUnreadable() {
        for (status, data, answer): (OSStatus, Data?, HotspotPasswordRead) in [
            (errSecSuccess, Data("fixture".utf8), .password("fixture")),
            (errSecItemNotFound, nil, .missing),
            (errSecInteractionNotAllowed, nil, .unreadable),
            (errSecAuthFailed, nil, .unreadable),
            (errSecSuccess, Data([0xff]), .unreadable)
        ] {
            let f = Fixture(); f.result = (status, data)
            XCTAssertEqual(f.read(), answer)
            XCTAssertEqual(f.switches, [false, true])
            XCTAssertTrue(f.prompt)
            XCTAssertEqual(f.deletes, 0)
        }
    }

    func testUnknownOrFailedPromptSwitchFailsBeforeCredentialRead() {
        let unknown = Fixture(); unknown.getStatus = errSecAuthFailed
        XCTAssertEqual(unknown.read(), .unreadable)
        XCTAssertEqual(unknown.reads, 0)
        XCTAssertTrue(unknown.switches.isEmpty)
        let failed = Fixture(); failed.switchResults = [errSecAuthFailed, errSecSuccess]
        XCTAssertEqual(failed.read(), .unreadable)
        XCTAssertEqual(failed.reads, 0)
        XCTAssertEqual(failed.switches, [false, true])
    }

    func testFailedRestorationIsReportedUnreadable() {
        let f = Fixture(); f.switchResults = [errSecSuccess, errSecAuthFailed]
        f.result = (errSecSuccess, Data("fixture".utf8))
        XCTAssertEqual(f.read(), .unreadable)
        XCTAssertEqual(f.switches, [false, true])
    }

    func testCancelledWorkDoesNotTouchKeychain() {
        let f = Fixture(); let permit = HotspotJoinPermit(); permit.cancel()
        XCTAssertEqual(f.read(permit), .unreadable)
        XCTAssertTrue(f.switches.isEmpty)
        XCTAssertEqual(f.reads, 0)
    }

    func testUnreadableSaveNeverDeletesOrAddsForeignItem() {
        let f = Fixture(); f.updateStatus = errSecAuthFailed
        let done = expectation(description: "save completed")
        f.store.save("fixture", ssid: "Fixture") { succeeded in
            XCTAssertFalse(succeeded); done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertEqual(f.deletes, 0)
        XCTAssertEqual(f.adds, 0)
        XCTAssertEqual(f.switches, [true, true])
    }

    func testExplicitSaveAndForgetRestorePreviousPromptPolicy() {
        let f = Fixture(); f.prompt = false; f.updateStatus = errSecItemNotFound
        let saved = expectation(description: "saved")
        f.store.save("fixture", ssid: "Fixture") { succeeded in XCTAssertTrue(succeeded); saved.fulfill() }
        wait(for: [saved], timeout: 2)
        XCTAssertEqual(f.adds, 1)
        XCTAssertFalse(f.prompt)
        let forgot = expectation(description: "forgotten")
        f.store.forget(ssid: "Fixture") { succeeded in XCTAssertTrue(succeeded); forgot.fulfill() }
        wait(for: [forgot], timeout: 2)
        XCTAssertFalse(f.prompt)
        XCTAssertEqual(f.deletes, 1)
        XCTAssertEqual(f.switches, [true, false, true, false])
    }
}

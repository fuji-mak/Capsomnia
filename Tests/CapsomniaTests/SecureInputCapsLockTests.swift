import XCTest
@testable import Capsomnia

final class SecureInputCapsLockPolicyTests: XCTestCase {
    private let secureField = SecureInputSnapshot(
        secureEventInputEnabled: true,
        focusedElementIsSecureTextField: true
    )

    func testActivatesOnlyWhenDedicatedModeAndCapsomniaAreOnInSecureField() {
        XCTAssertEqual(
            SecureInputCapsLockPolicy.action(
                dedicatedModeEnabled: true,
                capsomniaActive: true,
                overrideActive: false,
                snapshot: secureField
            ),
            .activate
        )
    }

    func testRequiresBothSecureInputAndSecureFieldFocus() {
        XCTAssertFalse(
            SecureInputCapsLockPolicy.shouldOverride(
                dedicatedModeEnabled: true,
                capsomniaActive: true,
                snapshot: SecureInputSnapshot(
                    secureEventInputEnabled: false,
                    focusedElementIsSecureTextField: true
                )
            )
        )
        XCTAssertFalse(
            SecureInputCapsLockPolicy.shouldOverride(
                dedicatedModeEnabled: true,
                capsomniaActive: true,
                snapshot: SecureInputSnapshot(
                    secureEventInputEnabled: true,
                    focusedElementIsSecureTextField: false
                )
            )
        )
    }

    func testRequiresDedicatedModeAndActiveCapsomnia() {
        XCTAssertFalse(
            SecureInputCapsLockPolicy.shouldOverride(
                dedicatedModeEnabled: false,
                capsomniaActive: true,
                snapshot: secureField
            )
        )
        XCTAssertFalse(
            SecureInputCapsLockPolicy.shouldOverride(
                dedicatedModeEnabled: true,
                capsomniaActive: false,
                snapshot: secureField
            )
        )
    }

    func testKeepsOverrideWhileSecureFieldRemainsFocused() {
        XCTAssertEqual(
            SecureInputCapsLockPolicy.action(
                dedicatedModeEnabled: true,
                capsomniaActive: true,
                overrideActive: true,
                snapshot: secureField
            ),
            .keepActive
        )
    }

    func testRestoresWhenFocusLeavesWhileCapsomniaRemainsOn() {
        XCTAssertEqual(
            SecureInputCapsLockPolicy.action(
                dedicatedModeEnabled: true,
                capsomniaActive: true,
                overrideActive: true,
                snapshot: SecureInputSnapshot(
                    secureEventInputEnabled: true,
                    focusedElementIsSecureTextField: false
                )
            ),
            .restore
        )
    }

    func testExplicitCapsomniaOffClearsOverrideWithoutRestoringCapsLock() {
        XCTAssertEqual(
            SecureInputCapsLockPolicy.action(
                dedicatedModeEnabled: true,
                capsomniaActive: false,
                overrideActive: true,
                snapshot: secureField
            ),
            .deactivateWithoutRestore
        )
    }

    func testSecureTextFieldSubroleMustMatchExactly() {
        XCTAssertTrue(SecureInputStateReader.isSecureTextField(subrole: "AXSecureTextField"))
        XCTAssertFalse(SecureInputStateReader.isSecureTextField(subrole: "AXTextField"))
        XCTAssertFalse(SecureInputStateReader.isSecureTextField(subrole: nil))
    }
}

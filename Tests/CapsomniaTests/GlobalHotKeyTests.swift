import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Capsomnia

final class GlobalHotKeyTests: XCTestCase {
    func testShortcutBuildsDisplayAndCarbonModifiers() {
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: [.control, .shift, .command],
            key: "k"
        )

        XCTAssertEqual(shortcut.displayTokens, ["⌃", "⇧", "⌘", "K"])
        XCTAssertEqual(shortcut.displayValue, "⌃⇧⌘K")
        XCTAssertEqual(
            shortcut.modifiers.carbonValue,
            UInt32(controlKey | shiftKey | cmdKey)
        )
    }

    func testCharacterShortcutRequiresCommandOptionOrControl() throws {
        let shiftOnly = try XCTUnwrap(makeKeyEvent(modifiers: [.shift]))
        let commandShift = try XCTUnwrap(
            makeKeyEvent(modifiers: [.command, .shift])
        )

        XCTAssertNil(KeyboardShortcut(event: shiftOnly))
        XCTAssertEqual(
            KeyboardShortcut(event: commandShift),
            KeyboardShortcut(
                keyCode: UInt32(kVK_ANSI_K),
                modifiers: [.shift, .command],
                key: "K"
            )
        )
    }

    func testShiftFunctionKeyShortcutIsAccepted() throws {
        let shiftF12 = try XCTUnwrap(
            makeFunctionKeyEvent(keyCode: kVK_F12, modifiers: [.shift])
        )

        XCTAssertEqual(
            KeyboardShortcut(event: shiftF12),
            KeyboardShortcut(
                keyCode: UInt32(kVK_F12),
                modifiers: [.shift],
                key: "F12"
            )
        )
    }

    func testFunctionKeyWithoutModifierIsRejected() throws {
        let f12 = try XCTUnwrap(
            makeFunctionKeyEvent(keyCode: kVK_F12, modifiers: [])
        )

        XCTAssertNil(KeyboardShortcut(event: f12))
    }

    func testShiftNonFunctionKeyRemainsRejected() throws {
        let shiftArrow = try XCTUnwrap(
            makeKeyEvent(
                keyCode: kVK_LeftArrow,
                modifiers: [.shift],
                characters: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
            )
        )

        XCTAssertNil(KeyboardShortcut(event: shiftArrow))
    }

    func testPreferencesPersistAndClearShortcut() {
        let previousShortcut = Preferences.keyboardShortcut
        defer { Preferences.keyboardShortcut = previousShortcut }

        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: [.option, .command],
            key: "K"
        )
        Preferences.keyboardShortcut = shortcut

        XCTAssertEqual(Preferences.keyboardShortcut, shortcut)

        Preferences.keyboardShortcut = nil
        XCTAssertNil(Preferences.keyboardShortcut)
    }

    @MainActor
    func testSystemRegistersAndUnregistersExclusiveShortcut() {
        _ = NSApplication.shared
        let manager = GlobalHotKeyManager()
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_F18),
            modifiers: [.shift],
            key: "F18"
        )

        XCTAssertEqual(manager.replaceShortcut(with: shortcut), noErr)
        XCTAssertEqual(manager.activeShortcut, shortcut)
        XCTAssertEqual(manager.replaceShortcut(with: nil), noErr)
        XCTAssertNil(manager.activeShortcut)
    }

    @MainActor
    func testCarbonHotKeyEventInvokesRegisteredHandler() throws {
        _ = NSApplication.shared
        let manager = GlobalHotKeyManager()
        var didTrigger = false
        manager.onTrigger = { didTrigger = true }

        var event: EventRef?
        XCTAssertEqual(
            CreateEvent(
                nil,
                OSType(kEventClassKeyboard),
                UInt32(kEventHotKeyPressed),
                GetCurrentEventTime(),
                EventAttributes(kEventAttributeNone),
                &event
            ),
            noErr
        )
        let unwrappedEvent = try XCTUnwrap(event)
        defer { ReleaseEvent(unwrappedEvent) }

        var hotKeyID = GlobalHotKeyManager.hotKeyID
        XCTAssertEqual(
            SetEventParameter(
                unwrappedEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                MemoryLayout<EventHotKeyID>.size,
                &hotKeyID
            ),
            noErr
        )
        XCTAssertEqual(
            SendEventToEventTarget(
                unwrappedEvent,
                GetApplicationEventTarget()
            ),
            noErr
        )
        XCTAssertTrue(didTrigger)
    }

    @MainActor
    func testRecorderCommitsAcceptedShortcutAndClearsIt() throws {
        _ = NSApplication.shared
        let recorder = ShortcutRecorderButton(
            placeholder: "Not Set",
            recording: "Press keys…",
            action: "Record",
            clear: "Clear",
            registrationFailed: "Unavailable"
        )
        var changes: [KeyboardShortcut?] = []
        var recordingStates: [Bool] = []
        recorder.onShortcutChange = {
            changes.append($0)
            return true
        }
        recorder.onRecordingChange = { recordingStates.append($0) }

        XCTAssertTrue(recorder.accessibilityPerformPress())
        recorder.keyDown(with: try XCTUnwrap(
            makeKeyEvent(modifiers: [.control, .option])
        ))

        XCTAssertEqual(recorder.title, "⌃⌥K")
        XCTAssertEqual(
            changes.last!,
            KeyboardShortcut(
                keyCode: UInt32(kVK_ANSI_K),
                modifiers: [.control, .option],
                key: "K"
            )
        )
        XCTAssertEqual(recordingStates, [true, false])

        XCTAssertTrue(recorder.accessibilityPerformPress())
        recorder.keyDown(with: try XCTUnwrap(makeDeleteEvent()))

        XCTAssertEqual(recorder.title, "Not Set")
        XCTAssertNil(changes.last!)
        XCTAssertEqual(recordingStates, [true, false, true, false])
    }

    @MainActor
    func testRecorderCancelEndsRecordingWithoutChangingShortcut() {
        _ = NSApplication.shared
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: [.command],
            key: "C"
        )
        let recorder = ShortcutRecorderButton(
            placeholder: "Not Set",
            recording: "Press keys…",
            action: "Record",
            clear: "Clear",
            registrationFailed: "Unavailable"
        )
        recorder.setShortcut(shortcut)
        var changes: [KeyboardShortcut?] = []
        var recordingStates: [Bool] = []
        recorder.onShortcutChange = {
            changes.append($0)
            return true
        }
        recorder.onRecordingChange = { recordingStates.append($0) }

        XCTAssertTrue(recorder.accessibilityPerformPress())
        XCTAssertEqual(recorder.title, "Press keys…")

        recorder.cancelRecording()

        XCTAssertEqual(recorder.title, shortcut.displayValue)
        XCTAssertTrue(changes.isEmpty)
        XCTAssertEqual(recordingStates, [true, false])
    }

    @MainActor
    func testRecorderShowsClearButtonWhileEditingRecordedShortcut() throws {
        _ = NSApplication.shared
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: [.command],
            key: "C"
        )
        let recorder = ShortcutRecorderButton(
            placeholder: "Not Set",
            recording: "Press keys…",
            action: "Record",
            clear: "Clear",
            registrationFailed: "Unavailable"
        )
        recorder.setShortcut(shortcut)
        var changes: [KeyboardShortcut?] = []
        var recordingStates: [Bool] = []
        recorder.onShortcutChange = {
            changes.append($0)
            return true
        }
        recorder.onRecordingChange = { recordingStates.append($0) }
        let clearButton: NSButton = try XCTUnwrap(
            descendants(of: recorder).first {
                $0.accessibilityLabel() == "Clear"
            }
        )
        XCTAssertTrue(clearButton.isHidden)

        XCTAssertTrue(recorder.accessibilityPerformPress())

        XCTAssertFalse(clearButton.isHidden)
        clearButton.frame = NSRect(
            origin: .zero,
            size: clearButton.intrinsicContentSize
        )
        XCTAssertTrue(
            clearButton.hitTest(
                NSPoint(
                    x: clearButton.bounds.midX,
                    y: clearButton.bounds.midY
                )
            ) === clearButton
        )
        clearButton.performClick(nil)
        XCTAssertEqual(recorder.title, "Not Set")
        XCTAssertNil(changes.last!)
        XCTAssertEqual(recordingStates, [true, false])
        XCTAssertTrue(clearButton.isHidden)
    }

    @MainActor
    func testRecorderKeepsPreviousShortcutWhenRegistrationFails() throws {
        _ = NSApplication.shared
        let previous = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: [.command],
            key: "C"
        )
        let recorder = ShortcutRecorderButton(
            placeholder: "Not Set",
            recording: "Press keys…",
            action: "Record",
            clear: "Clear",
            registrationFailed: "Unavailable"
        )
        recorder.setShortcut(previous)
        recorder.onShortcutChange = { _ in false }

        XCTAssertTrue(recorder.accessibilityPerformPress())
        recorder.keyDown(with: try XCTUnwrap(
            makeKeyEvent(modifiers: [.command, .shift])
        ))

        XCTAssertEqual(recorder.title, previous.displayValue)
        XCTAssertEqual(recorder.accessibilityValue() as? String, "Unavailable")
    }

    private func makeKeyEvent(
        modifiers: NSEvent.ModifierFlags
    ) -> NSEvent? {
        makeKeyEvent(
            keyCode: kVK_ANSI_K,
            modifiers: modifiers,
            characters: "k"
        )
    }

    private func makeFunctionKeyEvent(
        keyCode: Int,
        modifiers: NSEvent.ModifierFlags
    ) -> NSEvent? {
        makeKeyEvent(
            keyCode: keyCode,
            modifiers: modifiers,
            characters: ""
        )
    }

    private func makeKeyEvent(
        keyCode: Int,
        modifiers: NSEvent.ModifierFlags,
        characters: String
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )
    }

    private func makeDeleteEvent() -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{7f}",
            charactersIgnoringModifiers: "\u{7f}",
            isARepeat: false,
            keyCode: 51
        )
    }

    private func descendants<T: NSView>(of view: NSView) -> [T] {
        view.subviews.flatMap { child -> [T] in
            let current = (child as? T).map { [$0] } ?? []
            return current + descendants(of: child)
        }
    }
}

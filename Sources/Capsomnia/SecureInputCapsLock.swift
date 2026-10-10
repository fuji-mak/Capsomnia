import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

struct SecureInputSnapshot: Equatable {
    let secureEventInputEnabled: Bool
    let focusedElementIsSecureTextField: Bool
}

enum SecureInputCapsLockOverrideAction: Equatable {
    case none
    case activate
    case keepActive
    case restore
    case deactivateWithoutRestore
}

enum SecureInputCapsLockPolicy {
    static func shouldOverride(
        dedicatedModeEnabled: Bool,
        capsomniaActive: Bool,
        snapshot: SecureInputSnapshot
    ) -> Bool {
        dedicatedModeEnabled
            && capsomniaActive
            && snapshot.secureEventInputEnabled
            && snapshot.focusedElementIsSecureTextField
    }

    static func action(
        dedicatedModeEnabled: Bool,
        capsomniaActive: Bool,
        overrideActive: Bool,
        snapshot: SecureInputSnapshot
    ) -> SecureInputCapsLockOverrideAction {
        let shouldOverride = shouldOverride(
            dedicatedModeEnabled: dedicatedModeEnabled,
            capsomniaActive: capsomniaActive,
            snapshot: snapshot
        )

        if shouldOverride {
            return overrideActive ? .keepActive : .activate
        }
        guard overrideActive else { return .none }
        return capsomniaActive ? .restore : .deactivateWithoutRestore
    }
}

enum SecureInputStateReader {
    static func snapshot() -> SecureInputSnapshot {
        let secureEventInputEnabled = IsSecureEventInputEnabled()
        return SecureInputSnapshot(
            secureEventInputEnabled: secureEventInputEnabled,
            focusedElementIsSecureTextField: secureEventInputEnabled
                && focusedElementIsSecureTextField()
        )
    }

    static func isSecureTextField(subrole: String?) -> Bool {
        subrole == kAXSecureTextFieldSubrole as String
    }

    private static func focusedElementIsSecureTextField() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue,
        CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return false
        }

        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var subroleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSubroleAttribute as CFString,
            &subroleValue
        ) == .success else {
            return false
        }

        return isSecureTextField(subrole: subroleValue as? String)
    }
}

/// Focus notifications provide the fast path; the app's existing 250 ms poll
/// remains the fallback for apps that do not expose AX notifications.
final class SecureInputFocusMonitor {
    private let onChange: () -> Void
    private var workspaceObserver: NSObjectProtocol?
    private var observer: AXObserver?
    private var applicationElement: AXUIElement?
    private var processIdentifier: pid_t?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard workspaceObserver == nil else {
            attachToFrontmostApplication()
            return
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.attachToFrontmostApplication()
            self?.onChange()
        }
        attachToFrontmostApplication()
    }

    func stop() {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
        detachFromApplication()
    }

    fileprivate func focusDidChange() {
        onChange()
    }

    private func attachToFrontmostApplication() {
        guard AccessibilityPermission.isTrusted(prompt: false),
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            detachFromApplication()
            return
        }
        guard processIdentifier != pid || observer == nil else { return }

        detachFromApplication()
        var createdObserver: AXObserver?
        guard AXObserverCreate(pid, secureInputFocusObserverCallback, &createdObserver) == .success,
              let createdObserver else {
            return
        }

        let applicationElement = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let focusedElementResult = AXObserverAddNotification(
            createdObserver,
            applicationElement,
            kAXFocusedUIElementChangedNotification as CFString,
            context
        )
        let focusedWindowResult = AXObserverAddNotification(
            createdObserver,
            applicationElement,
            kAXFocusedWindowChangedNotification as CFString,
            context
        )
        let observesFocus = focusedElementResult == .success
            || focusedElementResult == .notificationAlreadyRegistered
            || focusedWindowResult == .success
            || focusedWindowResult == .notificationAlreadyRegistered
        guard observesFocus else { return }

        observer = createdObserver
        self.applicationElement = applicationElement
        processIdentifier = pid
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(createdObserver),
            .commonModes
        )
    }

    private func detachFromApplication() {
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            if let applicationElement {
                AXObserverRemoveNotification(
                    observer,
                    applicationElement,
                    kAXFocusedUIElementChangedNotification as CFString
                )
                AXObserverRemoveNotification(
                    observer,
                    applicationElement,
                    kAXFocusedWindowChangedNotification as CFString
                )
            }
        }
        observer = nil
        applicationElement = nil
        processIdentifier = nil
    }
}

private let secureInputFocusObserverCallback: AXObserverCallback = {
    _, _, notification, context in
    guard let context else { return }
    let notificationName = notification as String
    guard notificationName == kAXFocusedUIElementChangedNotification
        || notificationName == kAXFocusedWindowChangedNotification else {
        return
    }

    let monitor = Unmanaged<SecureInputFocusMonitor>
        .fromOpaque(context)
        .takeUnretainedValue()
    monitor.focusDidChange()
}

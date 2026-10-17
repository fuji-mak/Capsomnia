import AppKit
import Darwin
import UserNotifications

/// Uses the system login framework without root privileges or synthesized keystrokes.
/// The private entry point may disappear; failure is reported, never treated as a lock.
enum ScreenLock {
    private typealias LockFunction = @convention(c) () -> Void
    private static let framework = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY | RTLD_LOCAL)

    static var isAvailable: Bool {
        guard let framework else { return false }
        return dlsym(framework, "SACLockScreenImmediate") != nil
    }

    static func request() -> Bool {
        guard let framework, let symbol = dlsym(framework, "SACLockScreenImmediate") else { return false }
        unsafeBitCast(symbol, to: LockFunction.self)()
        return true
    }

    static func isLocked() -> Bool? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        if let locked = session["CGSSessionScreenIsLocked"] as? NSNumber {
            return locked.boolValue
        }
        // The key is absent for an unlocked console session. A background user
        // session is unknown, not an unlock (and must not display the notice).
        guard (session[kCGSessionOnConsoleKey as String] as? NSNumber)?.boolValue == true else { return nil }
        return false
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func notify(_ record: LidOpenLockRecord) {
        let center = UNUserNotificationCenter.current()
        let text = LidOpenLockText.current
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Capsomnia · " + text.confirmed
            content.body = text.details(record)
            center.add(UNNotificationRequest(identifier: "lid-open-lock-" + record.id.uuidString,
                                             content: content, trigger: nil))
        }
    }
}

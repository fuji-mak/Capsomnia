import AppKit

enum ScreenSession {
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

}

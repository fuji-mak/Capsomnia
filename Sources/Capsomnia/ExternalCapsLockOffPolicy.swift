enum ExternalCapsLockOffPolicy {
    /// Decide whether a Caps Lock turn-off should be treated as external and
    /// re-asserted instead of followed. While the lid is closed the built-in
    /// keyboard cannot be pressed, so a turn-off observed in that window
    /// comes from an external source unless the app itself initiated it.
    ///
    /// - An elapsed auto-off timer is an explicit turn-off that must proceed
    ///   to system sleep, so an in-progress auto-off always wins over the
    ///   guard.
    /// - `clamshellClosed == nil` (state unavailable) fails open: the
    ///   turn-off is honored as usual.
    static func shouldReassert(
        preferenceEnabled: Bool,
        sleepPreventionActive: Bool,
        recentUserAction: Bool,
        autoOffInProgress: Bool,
        clamshellClosed: Bool?
    ) -> Bool {
        preferenceEnabled
            && sleepPreventionActive
            && !recentUserAction
            && !autoOffInProgress
            && clamshellClosed == true
    }
}

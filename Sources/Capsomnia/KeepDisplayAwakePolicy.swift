enum KeepDisplayAwakePolicy {
    /// The display assertion follows the confirmed sleep-prevention state,
    /// not the raw Caps Lock state: while the helper is failing, holding the
    /// assertion would silently keep partial sleep prevention active (a
    /// display assertion also blocks idle system sleep) even though the app
    /// reports the error state. Failing closed matches the rest of the app.
    static func shouldHoldAssertion(
        preferenceEnabled: Bool,
        capsLockOn: Bool,
        sleepPreventionConfirmed: Bool
    ) -> Bool {
        preferenceEnabled && capsLockOn && sleepPreventionConfirmed
    }
}

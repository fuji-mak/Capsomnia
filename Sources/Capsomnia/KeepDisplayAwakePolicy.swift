enum KeepDisplayAwakePolicy {
    static func shouldHoldAssertion(preferenceEnabled: Bool, capsLockOn: Bool) -> Bool {
        preferenceEnabled && capsLockOn
    }
}

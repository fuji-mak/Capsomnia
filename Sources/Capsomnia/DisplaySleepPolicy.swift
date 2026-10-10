enum DisplaySleepPolicy {
    static func shouldRequestDisplaySleep(
        keepDisplayAwake: Bool,
        externalDisplayConnected: Bool?
    ) -> Bool {
        !keepDisplayAwake && externalDisplayConnected == false
    }
}

enum DisplaySleepPolicy {
    static func shouldRequestDisplaySleep(externalDisplayConnected: Bool?) -> Bool {
        externalDisplayConnected == false
    }
}

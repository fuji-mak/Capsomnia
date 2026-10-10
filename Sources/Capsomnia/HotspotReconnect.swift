import Foundation
import Network

struct HotspotReconnectConfiguration: Equatable {
    var enabled = false
    var ssid = ""

    init(enabled: Bool = false, ssid: String = "") {
        self.enabled = enabled
        self.ssid = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum HotspotReconnectStatus: Equatable {
    case disabled, sessionInactive, needsSSID, ready, waiting, joining
    case needsLocation, passwordMissing, passwordUnreadable
    case targetNotVisible, interfaceUnavailable, associationFailed
}

enum HotspotPasswordRead: Equatable {
    case password(String), missing, unreadable
}

enum HotspotJoinResult: Equatable {
    case associated, cancelled, targetNotVisible, interfaceUnavailable, failed
}

struct HotspotOutageMachine {
    private(set) var deadline: TimeInterval?
    private(set) var attempts = 0
    private(set) var isOutage = false

    mutating func pathChanged(satisfied: Bool, now: TimeInterval) {
        if satisfied {
            self = HotspotOutageMachine()
        } else if !isOutage {
            isOutage = true
            deadline = now + 5
        }
    }

    mutating func beginAttempt(now: TimeInterval) -> Bool {
        guard let deadline, now >= deadline else { return false }
        self.deadline = nil
        attempts += 1
        return true
    }

    mutating func attemptFinished(now: TimeInterval) {
        guard isOutage else { return }
        let delays: [TimeInterval] = [5, 10, 20, 30]
        deadline = now + delays[min(max(attempts - 1, 0), delays.count - 1)]
    }
}

final class HotspotJoinPermit {
    private let lock = NSLock()
    private var valid = true
    private let pathIsHealthy: () -> Bool

    init(pathIsHealthy: @escaping () -> Bool = { false }) {
        self.pathIsHealthy = pathIsHealthy
    }

    func cancel() {
        lock.lock()
        valid = false
        lock.unlock()
    }

    var canProceed: Bool {
        lock.lock()
        let current = valid
        lock.unlock()
        return current && !pathIsHealthy()
    }
}

struct HotspotReconnectDependencies {
    // Completion handlers and path updates must be delivered on the main thread.
    var startPath: (@escaping (Bool) -> Void) -> (() -> Void)
    var pathIsHealthy: () -> Bool
    var locationAllowed: () -> Bool
    var readPassword: (String, HotspotJoinPermit, @escaping (HotspotPasswordRead) -> Void) -> Void
    var join: (String, String, HotspotJoinPermit, @escaping (HotspotJoinResult) -> Void) -> Void
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var schedule: (TimeInterval, @escaping () -> Void) -> (() -> Void) = { delay, action in
        let timer = Timer(timeInterval: delay, repeats: false) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        return { timer.invalidate() }
    }
}

/// Call only on the main thread. One physical job remains occupied until its callback,
/// even after cancellation, because CoreWLAN association cannot be interrupted.
final class HotspotReconnectService {
    private let dependencies: HotspotReconnectDependencies
    private let onStatus: (HotspotReconnectStatus) -> Void
    private(set) var status: HotspotReconnectStatus = .disabled
    private var configuration = HotspotReconnectConfiguration()
    private var active = false
    private var generation: UInt64 = 0
    private var monitorGeneration: UInt64 = 0
    private var machine = HotspotOutageMachine()
    private var stopPath: (() -> Void)?
    private var cancelTimer: (() -> Void)?
    private var permit: HotspotJoinPermit?
    private var jobInFlight = false

    init(dependencies: HotspotReconnectDependencies, onStatus: @escaping (HotspotReconnectStatus) -> Void = { _ in }) {
        self.dependencies = dependencies
        self.onStatus = onStatus
    }

    func setActive(_ capsLockOn: Bool, configuration: HotspotReconnectConfiguration) {
        precondition(Thread.isMainThread)
        guard self.configuration != configuration || active != capsLockOn else { return }
        reset()
        self.configuration = configuration
        active = capsLockOn
        startIfNeeded()
    }

    func invalidateCredentialsOrPermission() {
        precondition(Thread.isMainThread)
        reset()
        startIfNeeded()
    }

    func stop() {
        precondition(Thread.isMainThread)
        reset()
        active = false
        publish(.disabled)
    }

    private func reset() {
        generation += 1
        monitorGeneration += 1
        permit?.cancel()
        permit = nil
        cancelTimer?()
        cancelTimer = nil
        stopPath?()
        stopPath = nil
        machine = HotspotOutageMachine()
    }

    private func startIfNeeded() {
        guard configuration.enabled else { publish(.disabled); return }
        guard !configuration.ssid.isEmpty else { publish(.needsSSID); return }
        guard active else { publish(.sessionInactive); return }
        publish(.ready)
        let current = monitorGeneration
        stopPath = dependencies.startPath { [weak self] satisfied in
            guard let self, self.monitorGeneration == current else { return }
            self.pathChanged(satisfied: satisfied)
        }
    }

    private func pathChanged(satisfied: Bool) {
        precondition(Thread.isMainThread)
        let wasOutage = machine.isOutage
        machine.pathChanged(satisfied: satisfied, now: dependencies.now())
        if satisfied {
            if wasOutage { generation += 1 }
            permit?.cancel()
            permit = nil
            cancelTimer?()
            cancelTimer = nil
            publish(.ready)
        } else if !wasOutage {
            publish(.waiting)
            scheduleAttempt()
        }
    }

    private func scheduleAttempt() {
        guard let deadline = machine.deadline else { return }
        cancelTimer?()
        let current = generation
        cancelTimer = dependencies.schedule(max(0, deadline - dependencies.now())) { [weak self] in
            guard let self, self.generation == current else { return }
            self.cancelTimer = nil
            self.attempt()
        }
    }

    private func attempt() {
        guard !jobInFlight else { return }
        guard !dependencies.pathIsHealthy() else { pathChanged(satisfied: true); return }
        guard machine.beginAttempt(now: dependencies.now()) else { scheduleAttempt(); return }
        guard dependencies.locationAllowed() else { finish(status: .needsLocation); return }
        let current = generation
        let permit = HotspotJoinPermit(pathIsHealthy: dependencies.pathIsHealthy)
        self.permit = permit
        let ssid = configuration.ssid
        guard permit.canProceed else { pathChanged(satisfied: true); return }
        jobInFlight = true
        publish(.joining)
        dependencies.readPassword(ssid, permit) { [weak self] result in
            guard let self else { return }
            precondition(Thread.isMainThread)
            guard self.generation == current, permit.canProceed else {
                self.jobCompletedStale()
                return
            }
            switch result {
            case .missing:
                self.jobInFlight = false
                self.finish(status: .passwordMissing)
            case .unreadable:
                self.jobInFlight = false
                self.finish(status: .passwordUnreadable)
            case .password(let password):
                self.dependencies.join(ssid, password, permit) { [weak self] result in
                    guard let self else { return }
                    precondition(Thread.isMainThread)
                    self.jobInFlight = false
                    guard self.generation == current, permit.canProceed else {
                        self.resumeCurrentOutage()
                        return
                    }
                    switch result {
                    case .associated: self.finish(status: .waiting)
                    case .targetNotVisible: self.finish(status: .targetNotVisible)
                    case .interfaceUnavailable: self.finish(status: .interfaceUnavailable)
                    case .failed: self.finish(status: .associationFailed)
                    case .cancelled: self.finish(status: .waiting)
                    }
                }
            }
        }
    }

    private func jobCompletedStale() {
        jobInFlight = false
        resumeCurrentOutage()
    }

    private func resumeCurrentOutage() {
        guard machine.isOutage else { return }
        if dependencies.pathIsHealthy() { pathChanged(satisfied: true); return }
        if machine.deadline == nil { machine.attemptFinished(now: dependencies.now()) }
        scheduleAttempt()
    }

    private func finish(status: HotspotReconnectStatus) {
        publish(status)
        machine.attemptFinished(now: dependencies.now())
        scheduleAttempt()
    }

    private func publish(_ status: HotspotReconnectStatus) {
        guard self.status != status else { return }
        self.status = status
        onStatus(status)
    }
}

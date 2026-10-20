import XCTest
@testable import Capsomnia

final class HotspotReconnectTests: XCTestCase {
    private final class TimerJob {
        let delay: TimeInterval
        let action: () -> Void
        var cancelled = false
        init(_ delay: TimeInterval, _ action: @escaping () -> Void) { self.delay = delay; self.action = action }
        func fire() { if !cancelled { cancelled = true; action() } }
    }
    private final class Harness {
        var now: TimeInterval = 0
        var healthy = false
        var healthRead: (() -> Bool)?
        var allowed = true
        var paths: [(Bool) -> Void] = []
        var stops = 0
        var timers: [TimerJob] = []
        var reads: [(HotspotPasswordRead) -> Void] = []
        var joins: [(HotspotJoinResult) -> Void] = []
        var permits: [HotspotJoinPermit] = []
        lazy var service = HotspotReconnectService(dependencies: HotspotReconnectDependencies(
            startPath: { [unowned self] callback in
                paths.append(callback)
                return { self.stops += 1 }
            },
            pathIsHealthy: { [unowned self] in healthRead?() ?? healthy },
            locationAllowed: { [unowned self] in allowed },
            readPassword: { [unowned self] _, permit, callback in permits.append(permit); reads.append(callback) },
            join: { [unowned self] _, _, permit, callback in permits.append(permit); joins.append(callback) },
            now: { [unowned self] in now },
            schedule: { [unowned self] delay, action in
                let timer = TimerJob(delay, action)
                timers.append(timer)
                return { timer.cancelled = true }
            }
        ))
        func start(_ ssid: String = "Phone") {
            service.setActive(true, configuration: HotspotReconnectConfiguration(enabled: true, ssid: ssid))
        }
        func path(_ healthy: Bool) { self.healthy = healthy; paths.last?(healthy) }
        func fire(after delay: TimeInterval) { now += delay; timers.last?.fire() }
    }

    func testPureOutageDelaysAndCappedBackoff() {
        var machine = HotspotOutageMachine()
        machine.pathChanged(satisfied: false, now: 100)
        machine.pathChanged(satisfied: false, now: 103)
        XCTAssertFalse(machine.beginAttempt(now: 104.999))
        XCTAssertEqual(machine.deadline, 105)
        var now: TimeInterval = 105
        for delay in [TimeInterval(5), 10, 20, 30, 30] {
            XCTAssertTrue(machine.beginAttempt(now: now))
            XCTAssertFalse(machine.beginAttempt(now: now))
            machine.attemptFinished(now: now)
            XCTAssertEqual(machine.deadline, now + delay)
            now += delay
        }
        machine.pathChanged(satisfied: true, now: now)
        XCTAssertEqual(machine.attempts, 0)
        XCTAssertNil(machine.deadline)
        machine.pathChanged(satisfied: false, now: now)
        XCTAssertEqual(machine.deadline, now + 5)
    }

    func testHealthyUpdatesDoNotRestartMonitorOrReadCredentials() {
        let h = Harness(); h.start()
        for _ in 0..<5 { h.path(true) }
        XCTAssertEqual(h.paths.count, 1)
        XCTAssertEqual(h.stops, 0)
        XCTAssertTrue(h.timers.isEmpty)
        XCTAssertTrue(h.reads.isEmpty)
        XCTAssertEqual(h.service.status, .ready)
    }

    func testOptInSSIDAndRawSessionRequired() {
        let h = Harness()
        h.service.setActive(true, configuration: HotspotReconnectConfiguration(ssid: "Phone"))
        XCTAssertTrue(h.paths.isEmpty)
        h.service.setActive(true, configuration: HotspotReconnectConfiguration(enabled: true, ssid: "   "))
        XCTAssertEqual(h.service.status, .needsSSID)
        h.service.setActive(false, configuration: HotspotReconnectConfiguration(enabled: true, ssid: "Phone"))
        XCTAssertEqual(h.service.status, .sessionInactive)
        XCTAssertTrue(h.paths.isEmpty)
        h.start(); XCTAssertEqual(h.paths.count, 1)
    }

    func testEarlyTimerAndPathFlapCannotJoin() {
        let h = Harness(); h.start(); h.path(false)
        h.fire(after: 4)
        XCTAssertTrue(h.reads.isEmpty)
        XCTAssertEqual(h.timers.last?.delay, 1)
        h.path(true); h.fire(after: 1)
        XCTAssertTrue(h.reads.isEmpty)
        h.path(false); h.fire(after: 5)
        XCTAssertEqual(h.reads.count, 1)
    }

    func testRecoveryStopAndReconfigurationCancelPendingCredentialRead() {
        for action in 0..<4 {
            let h = Harness(); h.start(); h.path(false); h.fire(after: 5)
            XCTAssertEqual(h.reads.count, 1)
            switch action {
            case 0: h.path(true)
            case 1: h.service.stop()
            case 2: h.start("Other")
            default: h.service.invalidateCredentialsOrPermission()
            }
            XCTAssertFalse(h.permits[0].canProceed)
            h.reads[0](.password("fixture"))
            XCTAssertTrue(h.joins.isEmpty)
            XCTAssertTrue(h.timers.allSatisfy { $0.cancelled })
        }
    }

    func testStaleJoinCannotOverlapNextSessionOrOverwriteStatus() {
        let h = Harness(); h.start(); h.path(false); h.fire(after: 5)
        h.reads[0](.password("fixture"))
        XCTAssertEqual(h.joins.count, 1)
        h.start("Other"); h.path(false); h.fire(after: 5)
        XCTAssertEqual(h.reads.count, 1)
        XCTAssertFalse(h.permits[0].canProceed)
        h.joins[0](.failed)
        XCTAssertEqual(h.service.status, .waiting)
        h.fire(after: 0)
        XCTAssertEqual(h.reads.count, 2)
        h.reads[1](.password("fixture"))
        XCTAssertEqual(h.joins.count, 2)
        h.path(true)
        h.joins[1](.failed)
        XCTAssertEqual(h.service.status, .ready)
    }

    func testHealthyBackendBeforeMainCallbackSuppressesCredentialAndJoinWork() {
        let h = Harness(); h.start(); h.path(false)
        h.healthy = true
        h.fire(after: 5)
        XCTAssertTrue(h.reads.isEmpty)
        XCTAssertEqual(h.service.status, .ready)
        h.path(false); h.fire(after: 5)
        h.healthy = true
        h.reads[0](.password("fixture"))
        XCTAssertTrue(h.joins.isEmpty)
        XCTAssertEqual(h.service.status, .ready)
    }

    func testRecoveryBetweenTimerHealthCheckAndPermitCreationResetsOutage() {
        let h = Harness(); h.start(); h.path(false)
        var checks = 0
        h.healthRead = { checks += 1; return checks >= 2 }
        h.fire(after: 5)
        XCTAssertTrue(h.reads.isEmpty)
        XCTAssertEqual(h.service.status, .ready)
        h.healthRead = nil
        h.path(false)
        XCTAssertEqual(h.timers.last?.delay, 5)
    }

    func testMissingUnreadableAndLocationHaveVisibleSafeStatusesAndBackoff() {
        for result in [HotspotPasswordRead.missing, .unreadable] {
            let h = Harness(); h.start(); h.path(false); h.fire(after: 5)
            h.reads[0](result)
            XCTAssertEqual(h.service.status, result == .missing ? .passwordMissing : .passwordUnreadable)
            XCTAssertTrue(h.joins.isEmpty)
            XCTAssertEqual(h.timers.last?.delay, 5)
            h.fire(after: 5); h.reads[1](result)
            XCTAssertEqual(h.timers.last?.delay, 10)
        }
        let h = Harness(); h.allowed = false; h.start(); h.path(false); h.fire(after: 5)
        XCTAssertEqual(h.service.status, .needsLocation)
        XCTAssertTrue(h.reads.isEmpty)
        XCTAssertEqual(h.timers.last?.delay, 5)
    }

    func testCancelledPathBackendCannotChangeNewMonitorCacheOrPublish() {
        var callbacks: [(Bool) -> Void] = []
        let path = HotspotWiFiPath(startMonitor: { callback in callbacks.append(callback); return {} })
        var updates: [Bool] = []
        let old = path.start { updates.append($0) }
        callbacks[0](true)
        old()
        let stop = path.start { updates.append($0) }
        XCTAssertFalse(path.isHealthy)
        callbacks[0](true)
        XCTAssertFalse(path.isHealthy)
        callbacks[1](false)
        let settled = expectation(description: "main callbacks settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertEqual(updates, [false])
        stop()
        callbacks[1](true)
        XCTAssertFalse(path.isHealthy)
    }

    func testJoinWorkerChecksCancellationAfterPendingScanBeforeAssociation() {
        for recover in [false, true] {
            let permit = HotspotJoinPermit()
            let entered = expectation(description: "scan entered")
            let done = expectation(description: "join completed")
            let gate = DispatchSemaphore(value: 0)
            var associated = false
            let worker = HotspotJoinWorker(scan: { _, _ in
                entered.fulfill()
                gate.wait()
                return .success { associated = true }
            })
            worker.join(ssid: "Fixture", password: "fixture", permit: permit) { result in
                XCTAssertEqual(result, recover ? .associated : .cancelled)
                done.fulfill()
            }
            wait(for: [entered], timeout: 2)
            if !recover { permit.cancel() }
            gate.signal()
            wait(for: [done], timeout: 2)
            XCTAssertEqual(associated, recover)
        }
    }
}

import XCTest
@testable import Capsomnia

final class MobileHotspotKeepAliveTests: XCTestCase {
    private func hotspotRoute() -> DefaultRoute {
        DefaultRoute(interface: "en0", gateway: "172.20.10.1", address: "172.20.10.3")
    }

    // MARK: - Route classification

    func testIPhoneHotspotRouteIsDetected() {
        XCTAssertTrue(
            MobileHotspotRoute.isMobileHotspot(
                gateway: "172.20.10.1",
                address: "172.20.10.3"
            )
        )
    }

    func testAndroidAndWindowsHotspotRoutesAreDetected() {
        XCTAssertTrue(
            MobileHotspotRoute.isMobileHotspot(
                gateway: "192.168.43.1",
                address: "192.168.43.55"
            )
        )
        XCTAssertTrue(
            MobileHotspotRoute.isMobileHotspot(
                gateway: "192.168.137.1",
                address: "192.168.137.44"
            )
        )
    }

    func testHomeRouterRouteIsNotDetected() {
        XCTAssertFalse(
            MobileHotspotRoute.isMobileHotspot(
                gateway: "192.168.1.1",
                address: "192.168.1.20"
            )
        )
    }

    func testMismatchedGatewayAndAddressAreNotDetected() {
        XCTAssertFalse(
            MobileHotspotRoute.isMobileHotspot(
                gateway: "172.20.10.1",
                address: "10.0.0.5"
            )
        )
    }

    func testMissingRoutePartsAreNotDetected() {
        XCTAssertFalse(MobileHotspotRoute.isMobileHotspot(gateway: nil, address: "172.20.10.3"))
        XCTAssertFalse(MobileHotspotRoute.isMobileHotspot(gateway: "172.20.10.1", address: nil))
        XCTAssertFalse(MobileHotspotRoute.isMobileHotspot(gateway: nil, address: nil))
    }

    // MARK: - Policy

    func testPolicyRunsOnlyWhenPreferenceOnAndCapsLockOn() {
        XCTAssertTrue(
            MobileHotspotKeepAlivePolicy.shouldRun(
                preferenceEnabled: true,
                capsLockOn: true
            )
        )
        XCTAssertFalse(
            MobileHotspotKeepAlivePolicy.shouldRun(
                preferenceEnabled: true,
                capsLockOn: false
            )
        )
        XCTAssertFalse(
            MobileHotspotKeepAlivePolicy.shouldRun(
                preferenceEnabled: false,
                capsLockOn: true
            )
        )
    }

    // MARK: - Tick behaviour

    func testTickPingsGatewayWhileOnHotspot() {
        var pings: [String] = []
        let keepAlive = MobileHotspotKeepAlive(
            routeProvider: { [self] in hotspotRoute() },
            pinger: { gateway in
                pings.append(gateway)
                return true
            }
        )

        keepAlive.tick()

        let expectation = expectation(description: "probe completes")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(pings, ["172.20.10.1"])
    }

    func testTickDoesNotPingOffHotspot() {
        var pings: [String] = []
        let keepAlive = MobileHotspotKeepAlive(
            routeProvider: {
                DefaultRoute(interface: "en0", gateway: "192.168.1.1", address: "192.168.1.20")
            },
            pinger: { gateway in
                pings.append(gateway)
                return true
            }
        )

        keepAlive.tick()
        XCTAssertTrue(pings.isEmpty)
    }

    func testTickDoesNotPingWithoutDefaultRoute() {
        var pings: [String] = []
        let keepAlive = MobileHotspotKeepAlive(
            routeProvider: { DefaultRoute(interface: nil, gateway: nil, address: nil) },
            pinger: { gateway in
                pings.append(gateway)
                return true
            }
        )

        keepAlive.tick()
        XCTAssertTrue(pings.isEmpty)
    }

    func testEnteringAndLeavingHotspotLogsTransitions() {
        var messages: [String] = []
        var onHotspot = true
        let keepAlive = MobileHotspotKeepAlive(
            routeProvider: {
                onHotspot
                    ? self.hotspotRoute()
                    : DefaultRoute(interface: "en0", gateway: "192.168.1.1", address: "192.168.1.20")
            },
            pinger: { _ in true },
            log: { messages.append($0) }
        )

        keepAlive.tick()
        onHotspot = false
        keepAlive.tick()

        XCTAssertTrue(messages.contains { $0.contains("detected") })
        XCTAssertTrue(messages.contains { $0.contains("left_hotspot") })
    }

    func testFailedProbeIsCountedAndLogged() {
        var messages: [String] = []
        let keepAlive = MobileHotspotKeepAlive(
            routeProvider: { [self] in hotspotRoute() },
            pinger: { _ in false },
            log: { messages.append($0) }
        )

        keepAlive.tick()

        let expectation = expectation(description: "probe completes")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2)

        XCTAssertTrue(messages.contains { $0.contains("probe_failed count=1") })
    }
}

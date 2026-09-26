import Foundation
import SystemConfiguration

/// The default route as seen through the SystemConfiguration dynamic store.
/// Reading the store instead of spawning `route` keeps the keep-alive probe
/// quiet — no subprocess, no extra CPU wake on the steady path.
struct DefaultRoute {
    let interface: String?
    let gateway: String?
    let address: String?

    static func current() -> DefaultRoute {
        guard let store = SCDynamicStoreCreate(nil, appName as CFString, nil, nil),
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                as? [String: Any]
        else {
            return DefaultRoute(interface: nil, gateway: nil, address: nil)
        }

        let interface = global["PrimaryInterface"] as? String
        let gateway = global["Router"] as? String

        var address: String?
        if let interface,
           let ipv4 = SCDynamicStoreCopyValue(
               store,
               "State:/Network/Interface/\(interface)/IPv4" as CFString
           ) as? [String: Any],
           let addresses = ipv4["Addresses"] as? [String] {
            address = addresses.first
        }

        return DefaultRoute(interface: interface, gateway: gateway, address: address)
    }
}

/// Phone hotspot subnets advertise themselves through the default route, which
/// is also what an iPhone Instant Hotspot connection reports even when legacy
/// AirPort APIs claim "not associated". Matching gateway + local address keeps
/// ordinary routers from being probed.
enum MobileHotspotRoute {
    static let knownGateways: Set<String> = [
        "172.20.10.1", // iPhone Personal Hotspot
        "192.168.43.1", // Android Personal Hotspot (legacy default)
        "192.168.137.1" // Windows Internet Connection Sharing
    ]

    static let knownAddressPrefixes: [String] = [
        "172.20.10.",
        "192.168.43.",
        "192.168.137."
    ]

    static func isMobileHotspot(gateway: String?, address: String?) -> Bool {
        guard let gateway, let address else { return false }
        return knownGateways.contains(gateway)
            && knownAddressPrefixes.contains { address.hasPrefix($0) }
    }
}

enum MobileHotspotKeepAlivePolicy {
    /// Follows the raw Caps Lock state rather than the helper-confirmed sleep
    /// state: keeping the link alive is harmless when sleep prevention fails,
    /// and the hotspot timeout does not wait for a pmset verdict.
    static func shouldRun(preferenceEnabled: Bool, capsLockOn: Bool) -> Bool {
        preferenceEnabled && capsLockOn
    }
}

/// Sends a single ICMP echo to the hotspot gateway on an interval so the phone
/// does not classify this Mac as idle and tear the hotspot down. Only probes
/// while the default route looks like a phone hotspot; ordinary Wi-Fi and
/// wired connections are never touched.
final class MobileHotspotKeepAlive {
    private let interval: TimeInterval
    private let routeProvider: () -> DefaultRoute
    private let pinger: (String) -> Bool
    private let log: (String) -> Void
    private var timer: Timer?
    private var onHotspot = false
    private var consecutiveProbeFailures = 0
    private var probeInFlight = false

    init(
        interval: TimeInterval = 60,
        routeProvider: @escaping () -> DefaultRoute = { DefaultRoute.current() },
        pinger: @escaping (String) -> Bool = { gateway in
            CommandRunner.run("/sbin/ping", ["-n", "-c", "1", "-W", "1000", gateway]).status == 0
        },
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.interval = interval
        self.routeProvider = routeProvider
        self.pinger = pinger
        self.log = log
    }

    var isActive: Bool {
        timer != nil
    }

    /// Idempotently starts or stops the timer. Safe to call on every apply
    /// pass; must be called on the main thread's run loop.
    @discardableResult
    func setActive(_ active: Bool) -> Bool {
        if active {
            guard timer == nil else { return true }
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.tick()
            }
            timer.tolerance = interval * 0.2
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            tick()
            return true
        }

        timer?.invalidate()
        timer = nil
        if onHotspot {
            log("hotspot_keepalive stopped")
        }
        onHotspot = false
        consecutiveProbeFailures = 0
        return true
    }

    func tick() {
        let route = routeProvider()
        guard MobileHotspotRoute.isMobileHotspot(
            gateway: route.gateway,
            address: route.address
        ), let gateway = route.gateway else {
            if onHotspot {
                log(
                    "hotspot_keepalive left_hotspot interface=\(route.interface ?? "none")"
                        + " gateway=\(route.gateway ?? "none")"
                )
            }
            onHotspot = false
            consecutiveProbeFailures = 0
            return
        }

        if !onHotspot {
            log(
                "hotspot_keepalive detected interface=\(route.interface ?? "none")"
                    + " gateway=\(gateway) address=\(route.address ?? "none")"
            )
        }
        onHotspot = true

        guard !probeInFlight else { return }
        probeInFlight = true
        DispatchQueue.global(qos: .utility).async { [pinger] in
            let succeeded = pinger(gateway)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.probeInFlight = false
                if succeeded {
                    if self.consecutiveProbeFailures > 0 {
                        self.log("hotspot_keepalive probe_recovered")
                    }
                    self.consecutiveProbeFailures = 0
                } else {
                    self.consecutiveProbeFailures += 1
                    self.log("hotspot_keepalive probe_failed count=\(self.consecutiveProbeFailures)")
                }
            }
        }
    }
}

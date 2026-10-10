import AppKit
import CoreLocation
import CoreWLAN
import Network
import LocalAuthentication
import Security

// Hotspot behavior and login Keychain prompt handling adapt Insomnia's MIT source.
// The full notice is bundled as Insomnia-MIT-LICENSE.
/// All Capsomnia Keychain calls, including explicit edits, share this queue because
/// the login Keychain prompt switch is process-wide. Query UI flags alone do not cover it.
final class HotspotPasswordStore {
    struct Operations {
        var getPrompts: () -> (OSStatus, Bool)
        var setPrompts: (Bool) -> OSStatus
        var read: ([String: Any]) -> (OSStatus, Data?)
        var update: ([String: Any], [String: Any]) -> OSStatus
        var add: ([String: Any]) -> OSStatus
        var delete: ([String: Any]) -> OSStatus

        static let system = Operations(
            getPrompts: {
                var enabled = DarwinBoolean(false)
                let status = SecKeychainGetUserInteractionAllowed(&enabled)
                return (status, enabled.boolValue)
            },
            setPrompts: { SecKeychainSetUserInteractionAllowed($0) },
            read: { query in
                var result: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                return (status, result as? Data)
            },
            update: { SecItemUpdate($0 as CFDictionary, $1 as CFDictionary) },
            add: { SecItemAdd($0 as CFDictionary, nil) },
            delete: { SecItemDelete($0 as CFDictionary) }
        )
    }

    private static let queue = DispatchQueue(label: "com.github.fuji-mak.capsomnia.hotspot-keychain")
    private let operations: Operations
    private let service: String

    init(service: String = "com.github.fuji-mak.capsomnia.hotspot", operations: Operations = .system) {
        self.service = service
        self.operations = operations
    }

    private func query(_ ssid: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: ssid]
    }

    private func withPrompts(_ allowed: Bool, operation: () -> Bool) -> Bool {
        let (status, previous) = operations.getPrompts()
        guard status == errSecSuccess else { return false }
        let changed = operations.setPrompts(allowed) == errSecSuccess
        let succeeded = changed && operation()
        let restored = operations.setPrompts(previous) == errSecSuccess
        return succeeded && restored
    }

    func read(_ ssid: String, permit: HotspotJoinPermit, completion: @escaping (HotspotPasswordRead) -> Void) {
        Self.queue.async { [self] in
            var result: HotspotPasswordRead = .unreadable
            guard permit.canProceed else {
                DispatchQueue.main.async { completion(result) }
                return
            }
            let succeeded = withPrompts(false) {
                guard permit.canProceed else { return false }
                var query = self.query(ssid)
                query[kSecReturnData as String] = true
                query[kSecMatchLimit as String] = kSecMatchLimitOne
                let context = LAContext()
                context.interactionNotAllowed = true
                query[kSecUseAuthenticationContext as String] = context
                let (status, data) = operations.read(query)
                if status == errSecItemNotFound { result = .missing; return true }
                guard status == errSecSuccess, let data,
                      let password = String(data: data, encoding: .utf8), !password.isEmpty else { return false }
                result = .password(password)
                return true
            }
            let answer = succeeded ? result : .unreadable
            DispatchQueue.main.async { completion(answer) }
        }
    }

    /// Only an explicit Settings action may write or delete. An unreadable item is
    /// never removed to bypass access controls, including after a duplicate-item error.
    func save(_ password: String, ssid: String, completion: @escaping (Bool) -> Void) {
        guard !ssid.isEmpty, !password.isEmpty else { completion(false); return }
        Self.queue.async { [self] in
            let succeeded = withPrompts(true) {
                let query = self.query(ssid)
                let attributes = [kSecValueData as String: Data(password.utf8)]
                let status = operations.update(query, attributes)
                if status == errSecSuccess { return true }
                guard status == errSecItemNotFound else { return false }
                return operations.add(query.merging(attributes) { _, new in new }) == errSecSuccess
            }
            DispatchQueue.main.async { completion(succeeded) }
        }
    }

    func forget(ssid: String, completion: @escaping (Bool) -> Void) {
        guard !ssid.isEmpty else { completion(false); return }
        Self.queue.async { [self] in
            let succeeded = withPrompts(true) {
                let status = operations.delete(query(ssid))
                return status == errSecSuccess || status == errSecItemNotFound
            }
            DispatchQueue.main.async { completion(succeeded) }
        }
    }
}

final class HotspotJoinWorker {
    typealias Scan = (String, String) -> Result<() throws -> Void, ScanFailure>
    enum ScanFailure: Error { case interfaceUnavailable, targetNotVisible, failed }
    private let queue = DispatchQueue(label: "com.github.fuji-mak.capsomnia.hotspot-join")
    private let scan: Scan

    init(scan: @escaping Scan = HotspotJoinWorker.scanWiFi) { self.scan = scan }

    private static func scanWiFi(ssid: String, password: String) -> Result<() throws -> Void, ScanFailure> {
        guard let interface = CWWiFiClient.shared().interface() else { return .failure(.interfaceUnavailable) }
        do {
            // Use the filtered result even if Location Services redacts CWNetwork.ssid.
            let networks = try interface.scanForNetworks(withSSID: Data(ssid.utf8))
            guard let network = networks.first else { return .failure(.targetNotVisible) }
            return .success { try interface.associate(to: network, password: password) }
        } catch { return .failure(.failed) }
    }

    func join(ssid: String, password: String, permit: HotspotJoinPermit, completion: @escaping (HotspotJoinResult) -> Void) {
        queue.async { [scan] in
            guard permit.canProceed else { DispatchQueue.main.async { completion(.cancelled) }; return }
            let result = scan(ssid, password)
            guard permit.canProceed else { DispatchQueue.main.async { completion(.cancelled) }; return }
            let answer: HotspotJoinResult
            switch result {
            case .success(let associate):
                guard permit.canProceed else { DispatchQueue.main.async { completion(.cancelled) }; return }
                do { try associate(); answer = .associated } catch { answer = .failed }
            case .failure(.targetNotVisible): answer = .targetNotVisible
            case .failure(.interfaceUnavailable): answer = .interfaceUnavailable
            case .failure(.failed): answer = .failed
            }
            DispatchQueue.main.async { completion(answer) }
        }
    }
}

private final class HotspotLocationPermission: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onChange: (() -> Void)?
    override init() { super.init(); manager.delegate = self }
    var allowed: Bool { CLLocationManager.locationServicesEnabled() && manager.authorizationStatus == .authorizedAlways }
    func request() { manager.requestWhenInUseAuthorization() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { onChange?() }
}

final class HotspotWiFiPath {
    private let lock = NSLock()
    private var healthy = false
    private var generation: UInt64 = 0
    private let startMonitor: (@escaping (Bool) -> Void) -> (() -> Void)

    init(startMonitor: @escaping (@escaping (Bool) -> Void) -> (() -> Void) = { update in
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { update($0.status == .satisfied) }
        monitor.start(queue: DispatchQueue(label: "com.github.fuji-mak.capsomnia.wifi-path"))
        return { monitor.cancel() }
    }) { self.startMonitor = startMonitor }

    var isHealthy: Bool {
        lock.lock(); defer { lock.unlock() }
        return healthy
    }

    func start(_ update: @escaping (Bool) -> Void) -> (() -> Void) {
        lock.lock()
        generation += 1
        let current = generation
        healthy = false
        lock.unlock()
        let cancel = startMonitor { [weak self] healthy in
            guard let self else { return }
            self.lock.lock()
            guard self.generation == current else { self.lock.unlock(); return }
            self.healthy = healthy
            self.lock.unlock()
            DispatchQueue.main.async {
                self.lock.lock()
                let valid = self.generation == current
                self.lock.unlock()
                if valid { update(healthy) }
            }
        }
        return { [weak self] in
            if let self {
                self.lock.lock()
                if self.generation == current { self.generation += 1; self.healthy = false }
                self.lock.unlock()
            }
            cancel()
        }
    }
}

final class HotspotReconnectController {
    private let passwords = HotspotPasswordStore()
    private let location = HotspotLocationPermission()
    private let path = HotspotWiFiPath()
    let service: HotspotReconnectService

    init(onStatus: @escaping (HotspotReconnectStatus) -> Void) {
        let worker = HotspotJoinWorker()
        let passwords = self.passwords
        let location = self.location
        let path = self.path
        service = HotspotReconnectService(dependencies: HotspotReconnectDependencies(
            startPath: { path.start($0) },
            pathIsHealthy: { path.isHealthy },
            locationAllowed: { location.allowed },
            readPassword: { passwords.read($0, permit: $1, completion: $2) },
            join: { ssid, password, permit, completion in
                worker.join(ssid: ssid, password: password, permit: permit, completion: completion)
            }
        ), onStatus: onStatus)
        location.onChange = { [weak service] in service?.invalidateCredentialsOrPermission() }
    }

    func requestLocation() { location.request() }
    func savePassword(_ password: String, ssid: String, completion: @escaping (Bool) -> Void) {
        service.invalidateCredentialsOrPermission()
        passwords.save(password, ssid: ssid) { [weak self] succeeded in
            self?.service.invalidateCredentialsOrPermission()
            completion(succeeded)
        }
    }
    func forgetPassword(ssid: String, completion: @escaping (Bool) -> Void) {
        service.invalidateCredentialsOrPermission()
        passwords.forget(ssid: ssid) { [weak self] succeeded in
            self?.service.invalidateCredentialsOrPermission()
            completion(succeeded)
        }
    }
    static func openLocationSettings() { open("x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") }
    static func openWiFiSettings() { open("x-apple.systempreferences:com.apple.wifi-settings-extension") }
    private static func open(_ target: String) {
        if let url = URL(string: target) { NSWorkspace.shared.open(url) }
    }
}

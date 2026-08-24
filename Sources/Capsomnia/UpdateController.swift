import AppKit
import CoreServices
import Foundation

/// Checks GitHub releases for a newer version, downloads the installer
/// package on request, and offers to remove the download once the update is
/// installed. Decision logic lives in `UpdateCheck`; this type owns the
/// side effects (network, alerts, files).
final class UpdateController {
    static let autoCheckInterval: TimeInterval = 86_400

    /// Failed attempts never update `lastUpdateCheckAt`, so without a floor a
    /// flaky network would retry on every menu opening.
    static let minimumAttemptInterval: TimeInterval = 3_600

    private static let repository = "fuji-mak/Capsomnia"
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases/latest"
    )!

    /// Set while a newer version than the running one is known.
    private(set) var availableVersion: String?

    var onAvailableVersionChange: (() -> Void)?

    private let log: (String) -> Void
    private var isChecking = false
    private var promoteInFlightCheckToUserInitiated = false
    private var lastAttemptAt: Date?
    private var autoCheckTimer: Timer?

    private let currentVersion: String

    init(
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "0",
        log: @escaping (String) -> Void
    ) {
        self.currentVersion = currentVersion
        self.log = log

        if let lastKnown = Preferences.lastKnownReleaseVersion,
           UpdateCheck.isVersion(lastKnown, newerThan: currentVersion) {
            availableVersion = lastKnown
        }
    }

    deinit {
        autoCheckTimer?.invalidate()
    }

    // MARK: - Checking

    /// Keeps the daily check running even if the menu is never opened. The
    /// timer fires well below the check interval; `autoCheckIfDue` throttles.
    func startAutoCheckTimer() {
        guard autoCheckTimer == nil else { return }
        let timer = Timer(timeInterval: Self.minimumAttemptInterval, repeats: true) { [weak self] _ in
            self?.autoCheckIfDue()
        }
        timer.tolerance = 300
        RunLoop.main.add(timer, forMode: .common)
        autoCheckTimer = timer
    }

    func autoCheckIfDue() {
        guard Preferences.automaticUpdateChecks,
              UpdateCheck.shouldAutoCheck(
                  now: Date(),
                  lastCheckedAt: Preferences.lastUpdateCheckAt,
                  minimumInterval: Self.autoCheckInterval,
                  lastAttemptAt: lastAttemptAt,
                  minimumAttemptInterval: Self.minimumAttemptInterval
              ) else {
            return
        }
        check(userInitiated: false)
    }

    func checkNow() {
        check(userInitiated: true)
    }

    private func check(userInitiated: Bool) {
        guard !isChecking else {
            // A user request during an in-flight automatic check adopts that
            // check instead of being dropped, so its result still alerts.
            if userInitiated {
                promoteInFlightCheckToUserInitiated = true
            }
            return
        }
        isChecking = true
        lastAttemptAt = Date()
        log("update_check started user_initiated=\(userInitiated ? "yes" : "no")")

        let task = URLSession.shared.dataTask(with: Self.latestReleaseURL) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.handleCheckResult(data: data, error: error, userInitiated: userInitiated)
            }
        }
        task.resume()
    }

    private func handleCheckResult(data: Data?, error: Error?, userInitiated initiatedByUser: Bool) {
        isChecking = false
        let userInitiated = initiatedByUser || promoteInFlightCheckToUserInitiated
        promoteInFlightCheckToUserInitiated = false

        guard error == nil,
              let data,
              let latestVersion = UpdateCheck.parseLatestReleaseVersion(data) else {
            log("update_check failed error=\(error.map(String.init(describing:)) ?? "invalid_response")")
            if userInitiated {
                let strings = AppStrings.current()
                presentAlert(
                    title: strings.updateCheckFailedTitle,
                    body: strings.updateCheckFailedBody,
                    confirm: strings.done
                )
            }
            return
        }

        Preferences.lastUpdateCheckAt = Date()
        Preferences.lastKnownReleaseVersion = latestVersion
        let isNewer = UpdateCheck.isVersion(latestVersion, newerThan: currentVersion)
        log("update_check latest=\(latestVersion) current=\(currentVersion) newer=\(isNewer ? "yes" : "no")")

        let previousAvailableVersion = availableVersion
        availableVersion = isNewer ? latestVersion : nil
        if availableVersion != previousAvailableVersion {
            onAvailableVersionChange?()
        }

        guard userInitiated else { return }
        let strings = AppStrings.current()
        if isNewer {
            promptDownload(version: latestVersion)
        } else {
            presentAlert(
                title: strings.updateUpToDateTitle,
                body: String(format: strings.updateUpToDateBodyFormat, currentVersion),
                confirm: strings.done
            )
        }
    }

    // MARK: - Download

    func promptDownload(version: String) {
        let strings = AppStrings.current()
        let confirmed = presentAlert(
            title: strings.updateAvailableTitle,
            body: String(format: strings.updateAvailableBodyFormat, version, currentVersion),
            confirm: strings.updateDownloadAndInstall,
            cancel: strings.updateLater
        )
        if confirmed {
            downloadInstaller(version: version)
        }
    }

    private func downloadInstaller(version: String) {
        guard let downloadURL = URL(
            string: "https://github.com/\(Self.repository)/releases/download/v\(version)/Capsomnia-\(version).pkg"
        ) else { return }
        log("update_download started version=\(version)")

        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] location, response, error in
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let location, error == nil, httpStatus == 200 else {
                DispatchQueue.main.async {
                    self?.handleDownloadFailure(
                        reason: error.map(String.init(describing:)) ?? "http_\(httpStatus)"
                    )
                }
                return
            }

            // The temporary file is deleted when this handler returns, so move
            // it before hopping to the main queue. The app-owned caches folder
            // avoids the Downloads-folder privacy prompt, and the file is
            // removed automatically once the update is installed.
            let cachesDirectory = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(appName, isDirectory: true)
            var destination = cachesDirectory.appendingPathComponent("Capsomnia-\(version).pkg")
            do {
                try FileManager.default.createDirectory(
                    at: cachesDirectory,
                    withIntermediateDirectories: true
                )
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: location, to: destination)

                // URLSession downloads carry no quarantine attribute for a
                // non-sandboxed app, and quarantine is what makes Installer
                // run the package through Gatekeeper. Fail closed: without
                // the attribute the package is not opened.
                var quarantine = URLResourceValues()
                quarantine.quarantineProperties = [
                    kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
                    kLSQuarantineDataURLKey as String: downloadURL as NSURL
                ]
                try destination.setResourceValues(quarantine)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                DispatchQueue.main.async {
                    self?.handleDownloadFailure(reason: String(describing: error))
                }
                return
            }

            DispatchQueue.main.async {
                self?.handleDownloadSuccess(version: version, destination: destination)
            }
        }
        task.resume()
    }

    private func handleDownloadSuccess(version: String, destination: URL) {
        guard NSWorkspace.shared.open(destination) else {
            try? FileManager.default.removeItem(at: destination)
            handleDownloadFailure(reason: "installer_open_failed")
            return
        }
        Preferences.setPendingInstaller(path: destination.path, version: version)
        log("update_download finished path=\(destination.path)")
    }

    private func handleDownloadFailure(reason: String) {
        log("update_download failed error=\(reason)")
        let strings = AppStrings.current()
        presentAlert(
            title: strings.updateDownloadFailedTitle,
            body: strings.updateDownloadFailedBody,
            confirm: strings.done
        )
    }

    // MARK: - Installer cleanup

    /// Called at launch: once the app runs as the version a previously
    /// downloaded installer delivered, remove that download from the app's
    /// caches folder. The file never lives in a user-facing location, so no
    /// confirmation is needed.
    func cleanUpInstallerIfNeeded() {
        let action = UpdateCheck.installerCleanupAction(
            currentVersion: currentVersion,
            recordedPath: Preferences.pendingInstallerPath,
            recordedVersion: Preferences.pendingInstallerVersion,
            fileExists: { FileManager.default.fileExists(atPath: $0) }
        )

        switch action {
        case .none, .keepWaiting:
            return
        case .clearRecord:
            Preferences.setPendingInstaller(path: nil, version: nil)
        case let .remove(path):
            do {
                try FileManager.default.removeItem(atPath: path)
                log("update_installer_cleanup removed path=\(path)")
                Preferences.setPendingInstaller(path: nil, version: nil)
            } catch {
                // Keep the record so the next launch retries the removal.
                log("update_installer_cleanup failed error=\(String(describing: error))")
            }
        }
    }

    // MARK: - Alerts

    @discardableResult
    private func presentAlert(
        title: String,
        body: String,
        confirm: String,
        cancel: String? = nil
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: confirm)
        if let cancel {
            alert.addButton(withTitle: cancel)
        }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

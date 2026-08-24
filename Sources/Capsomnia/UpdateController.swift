import AppKit
import Foundation

/// Checks GitHub releases for a newer version, downloads the installer
/// package on request, and offers to remove the download once the update is
/// installed. Decision logic lives in `UpdateCheck`; this type owns the
/// side effects (network, alerts, files).
final class UpdateController {
    static let autoCheckInterval: TimeInterval = 86_400

    private static let repository = "fuji-mak/Capsomnia"
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases/latest"
    )!

    /// Set while a newer version than the running one is known.
    private(set) var availableVersion: String?

    var onAvailableVersionChange: (() -> Void)?

    private let log: (String) -> Void
    private var isChecking = false

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
        as? String ?? "0"

    init(log: @escaping (String) -> Void) {
        self.log = log
    }

    // MARK: - Checking

    func autoCheckIfDue() {
        guard Preferences.automaticUpdateChecks,
              UpdateCheck.shouldAutoCheck(
                  now: Date(),
                  lastCheckedAt: Preferences.lastUpdateCheckAt,
                  minimumInterval: Self.autoCheckInterval
              ) else {
            return
        }
        check(userInitiated: false)
    }

    func checkNow() {
        check(userInitiated: true)
    }

    private func check(userInitiated: Bool) {
        guard !isChecking else { return }
        isChecking = true
        log("update_check started user_initiated=\(userInitiated ? "yes" : "no")")

        let task = URLSession.shared.dataTask(with: Self.latestReleaseURL) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.handleCheckResult(data: data, error: error, userInitiated: userInitiated)
            }
        }
        task.resume()
    }

    private func handleCheckResult(data: Data?, error: Error?, userInitiated: Bool) {
        isChecking = false

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
            // it before hopping to the main queue.
            let destination = FileManager.default
                .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Capsomnia-\(version).pkg")
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
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
        Preferences.setPendingInstaller(path: destination.path, version: version)
        log("update_download finished path=\(destination.path)")
        NSWorkspace.shared.open(destination)
    }

    private func handleDownloadFailure(reason: String) {
        log("update_download failed error=\(reason)")
        let strings = AppStrings.current()
        presentAlert(
            title: strings.updateCheckFailedTitle,
            body: strings.updateCheckFailedBody,
            confirm: strings.done
        )
    }

    // MARK: - Installer cleanup

    /// Called at launch: once the app runs as the version a previously
    /// downloaded installer delivered, offer to move that download to the
    /// Trash. Declining clears the record so the question is asked only once.
    func offerInstallerCleanupIfNeeded() {
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
        case let .offerRemoval(path, _):
            let strings = AppStrings.current()
            let fileURL = URL(fileURLWithPath: path)
            let confirmed = presentAlert(
                title: strings.updateRemoveInstallerTitle,
                body: String(format: strings.updateRemoveInstallerBodyFormat, fileURL.lastPathComponent),
                confirm: strings.updateRemoveInstallerRemove,
                cancel: strings.updateRemoveInstallerKeep
            )
            if confirmed {
                do {
                    try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
                    log("update_installer_cleanup trashed path=\(path)")
                } catch {
                    log("update_installer_cleanup failed error=\(String(describing: error))")
                }
            } else {
                log("update_installer_cleanup kept path=\(path)")
            }
            Preferences.setPendingInstaller(path: nil, version: nil)
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

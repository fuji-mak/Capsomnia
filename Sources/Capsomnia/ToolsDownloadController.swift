import AppKit

/// Download and install optional tools in the app, keeping Installer component
/// choices and per-agent filesystem paths out of the user flow.
final class ToolsDownloadController {
    typealias Download = (URL, @escaping (Result<URL, Error>) -> Void) -> Void
    typealias Install = (URL, @escaping () -> Void, @escaping (Result<Void, Error>) -> Void) -> Void
    var onDownloadingChange: ((Bool) -> Void)?
    var onStatusChange: ((String?) -> Void)?
    private(set) var isDownloading = false
    private let download: Download
    private let install: Install

    init(download: @escaping Download = ToolsDownloadController.downloadPackage,
         install: @escaping Install = ToolsInstallation.install) {
        self.download = download
        self.install = install
    }

    func promptDownload(from window: NSWindow? = nil) {
        guard !isDownloading else { return }
        let text = ToolsDownloadText.current
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CapsomniaToolsPackageURL") as? String,
              let source = URL(string: value) else {
            showError(text.unavailable, for: window)
            return
        }
        let alert = NSAlert()
        alert.messageText = text.title
        alert.informativeText = text.body
        alert.addButton(withTitle: text.install)
        alert.addButton(withTitle: text.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        startDownload(from: source, window: window) { [weak self, weak window] result in
            // Administrator authentication belongs to another process. Restore the
            // initiating settings window before presenting the installation result.
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            switch result {
            case .success:
                self?.showMessage(ToolsDownloadText.current.completed, for: window)
            case .failure(let error):
                switch error {
                case ToolsInstallation.Failure.cancelled: break
                case ToolsInstallation.Failure.unsupportedPackage:
                    self?.showError(ToolsDownloadText.current.unavailable, for: window)
                default: self?.showError(ToolsDownloadText.current.failure, for: window)
                }
            }
        }
    }

    private func showError(_ body: String, for window: NSWindow?) {
        showMessage("CLI & Skill", body: body, style: .warning, for: window)
    }

    private func showMessage(_ title: String, body: String = "",
                             style: NSAlert.Style = .informational, for window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    func startDownload(from source: URL, window: NSWindow? = nil,
                       completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isDownloading else { return }
        isDownloading = true
        onDownloadingChange?(true)
        onStatusChange?(ToolsDownloadText.current.downloading)
        download(source) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let destination):
                    self.onStatusChange?(ToolsDownloadText.current.installing)
                    self.install(destination, { [weak window] in
                        // Restore the same window once authentication ends, without
                        // changing its level or preventing normal app switching.
                        NSApp.activate(ignoringOtherApps: true)
                        window?.makeKeyAndOrderFront(nil)
                    }) { [weak self] installed in
                        DispatchQueue.main.async {
                            self?.finish(installed.map { destination }, completion: completion)
                        }
                    }
                case .failure(let error):
                    self.finish(.failure(error), completion: completion)
                }
            }
        }
    }

    private func finish(_ result: Result<URL, Error>, completion: (Result<URL, Error>) -> Void) {
        isDownloading = false
        onDownloadingChange?(false)
        onStatusChange?(nil)
        completion(result)
    }

    enum DownloadError: Error { case invalidSource, invalidResponse, untrustedPackage }

    static func downloadPackage(from source: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // The preview points at a sibling local package. Releases use HTTPS.
        guard source.isFileURL || source.scheme == "https" else {
            completion(.failure(DownloadError.invalidSource))
            return
        }
        if source.isFileURL {
            DispatchQueue.global(qos: .userInitiated).async {
                completion(Result { try savePackage(at: source, source: source) })
            }
            return
        }
        URLSession.shared.downloadTask(with: source) { location, response, error in
            guard let location, error == nil,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  response?.url?.scheme == "https" else {
                completion(.failure(error ?? DownloadError.invalidResponse))
                return
            }
            // Copy before the completion handler returns and removes the temporary file.
            completion(Result { try savePackage(at: location, source: source) })
        }.resume()
    }

    static func savePackage(at location: URL, source: URL, cacheDirectory: URL? = nil) throws -> URL {
        let directory = cacheDirectory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Capsomnia/Tools", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var destination = directory.appendingPathComponent("Capsomnia-Tools-\(UUID().uuidString).pkg")
        do {
            try FileManager.default.copyItem(at: location, to: destination)
            if !source.isFileURL {
                let signature = CommandRunner.run("/usr/sbin/pkgutil", ["--check-signature", destination.path])
                guard UpdateCheck.installerSignatureIsTrusted(
                    exitStatus: signature.status, output: signature.stdout, teamID: developerTeamID
                ) else { throw DownloadError.untrustedPackage }
                var values = URLResourceValues()
                values.quarantineProperties = [
                    kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
                    kLSQuarantineDataURLKey as String: source as NSURL
                ]
                try destination.setResourceValues(values)
            }
            return destination
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}

struct ToolsDownloadText {
    let entryTitle: String
    var entryDescription: String { body }
    let title, body, install, cancel, downloading, installing, completed, unavailable, failure: String

    static var current: Self {
        switch Preferences.language {
        case .japanese:
            return Self(entryTitle: "Capsomnia CLI & Skillをダウンロード", title: "CLI・Skillをインストールしますか？",
                        body: "Capsomniaを操作するためのCLIとSkillをまとめてダウンロードします。",
                        install: "インストール", cancel: "キャンセル", downloading: "ダウンロード中…", installing: "インストール中…",
                        completed: "完了しました", unavailable: "対応する配布ファイルを準備中です。",
                        failure: "インストールを完了できませんでした。もう一度お試しください。")
        case .english:
            return Self(entryTitle: "Download Capsomnia CLI & Skill", title: "Install CLI & Skill?", body: "Download the CLI and Skill for controlling Capsomnia together.",
                        install: "Install", cancel: "Cancel", downloading: "Downloading…", installing: "Installing…",
                        completed: "Installation completed.", unavailable: "The compatible package is being prepared.",
                        failure: "Could not complete installation. Please try again.")
        case .korean:
            return Self(entryTitle: "Capsomnia CLI & Skill 다운로드", title: "CLI와 Skill을 설치할까요?", body: "Capsomnia를 제어하기 위한 CLI와 Skill을 함께 다운로드합니다.",
                        install: "설치", cancel: "취소", downloading: "다운로드 중…", installing: "설치 중…",
                        completed: "설치가 완료되었습니다.", unavailable: "호환되는 배포 파일을 준비 중입니다.",
                        failure: "설치를 완료하지 못했습니다. 다시 시도하세요.")
        case .simplifiedChinese:
            return Self(entryTitle: "下载 Capsomnia CLI & Skill", title: "要安装 CLI 和 Skill 吗？", body: "一起下载用于控制 Capsomnia 的 CLI 和 Skill。",
                        install: "安装", cancel: "取消", downloading: "正在下载…", installing: "正在安装…",
                        completed: "安装已完成。", unavailable: "正在准备兼容的发布文件。",
                        failure: "未能完成安装。请重试。")
        }
    }
}

import AppKit
import XCTest
@testable import Capsomnia

final class ToolsDownloadTests: XCTestCase {
    func testBusyStateIncludesInstallationAndRejectsDuplicateClick() {
        let source = URL(fileURLWithPath: "/tmp/source.pkg")
        let destination = URL(fileURLWithPath: "/tmp/downloaded.pkg")
        var downloaded: ((Result<URL, Error>) -> Void)?
        var installed: ((Result<Void, Error>) -> Void)?
        var downloads = 0
        var states: [Bool] = []
        let installing = expectation(description: "Installation begins after download")
        let controller = ToolsDownloadController(download: { _, done in
            downloads += 1
            downloaded = done
        }, install: { package, _, done in
            XCTAssertEqual(package, destination)
            installed = done
            installing.fulfill()
        })
        controller.onDownloadingChange = { states.append($0) }
        let done = expectation(description: "Verified installation finished")
        controller.startDownload(from: source) { result in
            XCTAssertEqual(try? result.get(), destination)
            done.fulfill()
        }
        XCTAssertNil(installed)
        downloaded?(.success(destination))
        wait(for: [installing], timeout: 2)
        XCTAssertTrue(controller.isDownloading)
        controller.startDownload(from: source) { _ in XCTFail("Duplicate installation") }
        XCTAssertEqual(downloads, 1)
        XCTAssertEqual(states, [true])
        installed?(.success(()))
        wait(for: [done], timeout: 2)
        XCTAssertEqual(states, [true, false])
    }

    func testAuthorizationNotificationArrivesBeforeInstallationEndsAndOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("authorized")
        let notified = expectation(description: "Authentication completed")
        notified.assertForOverFulfill = true
        var callbacks = 0
        let observer = ToolsInstallation.observeAuthorization(marker: marker) {
            XCTAssertTrue(Thread.isMainThread)
            callbacks += 1
            notified.fulfill()
        }
        defer { observer.cancel() }
        XCTAssertEqual(callbacks, 0)
        try Data().write(to: marker)
        wait(for: [notified], timeout: 2)
        let nextTicks = expectation(description: "No duplicate activation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nextTicks.fulfill() }
        wait(for: [nextTicks], timeout: 2)
        XCTAssertEqual(callbacks, 1)
    }

    func testDownloadFailureDoesNotInstallAndAllowsRetry() {
        var attempts = 0
        let controller = ToolsDownloadController(download: { _, done in
            attempts += 1
            done(.failure(ToolsDownloadController.DownloadError.invalidResponse))
        }, install: { _, _, _ in XCTFail("Failed download must not install") })
        for _ in 0..<2 {
            let done = expectation(description: "Failure delivered")
            controller.startDownload(from: URL(fileURLWithPath: "/tmp/missing.pkg")) { result in
                if case .success = result { XCTFail("Unexpected success") }
                done.fulfill()
            }
            wait(for: [done], timeout: 2)
            XCTAssertFalse(controller.isDownloading)
        }
        XCTAssertEqual(attempts, 2)
    }

    func testCancelledAuthenticationIsNotReportedAsSuccess() {
        let controller = ToolsDownloadController(download: { source, done in done(.success(source)) },
                                                 install: { _, _, done in done(.failure(ToolsInstallation.Failure.cancelled)) })
        let done = expectation(description: "Cancellation delivered")
        controller.startDownload(from: URL(fileURLWithPath: "/tmp/package.pkg")) { result in
            guard case .failure(let error) = result else { XCTFail("Unexpected success"); done.fulfill(); return }
            XCTAssertTrue(error is ToolsInstallation.Failure)
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertFalse(controller.isDownloading)
    }

    func testLocalPackageIsCopiedWithoutChangingSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.pkg")
        let contents = Data("local package fixture".utf8)
        try contents.write(to: source)
        let destination = try ToolsDownloadController.savePackage(
            at: source, source: source, cacheDirectory: root.appendingPathComponent("cache")
        )
        XCTAssertEqual(try Data(contentsOf: destination), contents)
        XCTAssertEqual(try Data(contentsOf: source), contents)
    }

    func testStatusRequiresBothCLIsAndSharedSkillsWithCorrectClaudeLinks() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        try fm.createDirectory(at: bin, withIntermediateDirectories: true)
        XCTAssertFalse(ToolsInstallationStatus.read(home: root, bin: bin).isComplete)
        for tool in ["cpsm", "macready"] {
            let file = bin.appendingPathComponent(tool)
            try Data("#!/bin/sh\n".utf8).write(to: file)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        for name in ["capsomnia", "macready"] {
            let shared = root.appendingPathComponent(".agents/skills/\(name)")
            let link = root.appendingPathComponent(".claude/skills/\(name)")
            try fm.createDirectory(at: shared, withIntermediateDirectories: true)
            try fm.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("name: \(name)".utf8).write(to: shared.appendingPathComponent("SKILL.md"))
            try fm.createSymbolicLink(at: link, withDestinationURL: shared)
        }
        XCTAssertTrue(ToolsInstallationStatus.read(home: root, bin: bin).isComplete)
        let wrong = root.appendingPathComponent(".claude/skills/capsomnia")
        try fm.removeItem(at: wrong)
        try fm.createSymbolicLink(at: wrong, withDestinationURL: root.appendingPathComponent(".agents/skills/macready"))
        XCTAssertFalse(ToolsInstallationStatus.read(home: root, bin: bin).skills)
    }

    func testLegacyPackageIsRejectedAndNewFormatIsAccepted() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let component = root.appendingPathComponent("fixture.pkg")
        let built = CommandRunner.run("/usr/bin/pkgbuild", ["--nopayload", "--identifier", "test.capsomnia.tools", "--version", "1.0", component.path])
        XCTAssertEqual(built.status, 0, built.stderr)
        for newFormat in [false, true] {
            let xml = root.appendingPathComponent("distribution.xml")
            let marker = newFormat ? "<!-- \(ToolsInstallation.formatMarker) -->" : ""
            try """
            <?xml version="1.0" encoding="utf-8"?>
            <installer-gui-script minSpecVersion="2">
              \(marker)
              <title>Fixture</title>
              <choices-outline><line choice="default" /></choices-outline>
              <choice id="default"><pkg-ref id="test.capsomnia.tools" /></choice>
              <pkg-ref id="test.capsomnia.tools" version="1.0">fixture.pkg</pkg-ref>
            </installer-gui-script>
            """.write(to: xml, atomically: true, encoding: .utf8)
            let package = root.appendingPathComponent(newFormat ? "new.pkg" : "old.pkg")
            let product = CommandRunner.run("/usr/bin/productbuild", ["--distribution", xml.path, "--package-path", root.path, package.path])
            XCTAssertEqual(product.status, 0, product.stderr)
            if newFormat {
                XCTAssertNoThrow(try ToolsInstallation.validateFormat(package))
            } else {
                XCTAssertThrowsError(try ToolsInstallation.validateFormat(package))
            }
            XCTAssertThrowsError(try ToolsDownloadController.savePackage(at: package, source: URL(string: "https://example.com/tools.pkg")!, cacheDirectory: root.appendingPathComponent("cache")), "Unsigned remote packages must be rejected")
        }
    }

    func testPackagePathIsShellQuoted() {
        let path = "/tmp/a' b\" $(touch NEVER) `echo bad` \\ file.pkg"
        let result = CommandRunner.run("/bin/sh", ["-c", "printf '%s' " + ToolsInstallation.shellQuote(path)])
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, path)
    }
}

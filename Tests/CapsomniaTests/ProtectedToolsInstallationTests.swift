import Foundation
import XCTest
@testable import Capsomnia

final class ProtectedToolsInstallationTests: XCTestCase {
    func testOriginalReplacementCannotChangeTheInstalledCopy() throws {
        try checkProtectedCopy(asRoot: false)
    }

    func testPrivilegedCopyIsInaccessibleToTheDownloadingUser() throws {
        guard getuid() != 0,
              CommandRunner.run("/usr/bin/sudo", ["-n", "/usr/bin/true"]).status == 0 else {
            throw XCTSkip("Requires passwordless sudo, available on the macOS CI runners")
        }
        try checkProtectedCopy(asRoot: true)
    }

    func testDownloadedPackageIsRecheckedAndUnsignedReplacementIsRejected() throws {
        try withFixture { root in
            let package = try makePackage(in: root, supportedFormat: true)
            // This is the package at the final boundary, after any earlier check.
            let result = run(package, in: root, requiresSignature: true, installer: "exit 99")
            XCTAssertNotEqual(result.status, 0)
            XCTAssertNotEqual(result.status, 99, "An unsigned replacement must not reach installer")
            assertStagingRemoved(result)
        }
    }

    func testFormatIsRecheckedOnTheCopyBeforeInstallation() throws {
        try withFixture { root in
            let package = try makePackage(in: root, supportedFormat: false)
            let result = run(package, in: root, requiresSignature: false, installer: "exit 99")
            XCTAssertNotEqual(result.status, 0)
            XCTAssertNotEqual(result.status, 99, "An unsupported replacement must not reach installer")
            assertStagingRemoved(result)
        }
    }

    private func checkProtectedCopy(asRoot: Bool) throws {
        try withFixture { root in
            let package = try makePackage(in: root, supportedFormat: true)
            let originalHash = CommandRunner.run("/usr/bin/shasum", ["-a", "256", package.path])
                .stdout.split(separator: " ").first!
            let denyUserAccess = asRoot ? """
            if /usr/bin/sudo -u '#\(getuid())' /bin/cat "$2" >/dev/null 2>&1; then exit 98; fi
            """ : ""
            let result = run(package, in: root, requiresSignature: false, asRoot: asRoot, installer: """
            # Replace the original after validation, just before consuming the pkg.
            printf 'replacement' > \(ToolsInstallation.shellQuote(package.path))
            \(denyUserAccess)
            /usr/bin/stat -f 'package-owner=%u mode=%Lp' "$2"
            /usr/bin/stat -f 'directory-owner=%u mode=%Lp' "$(/usr/bin/dirname "$2")"
            /usr/bin/shasum -a 256 "$2"
            """)
            XCTAssertEqual(result.status, 0, result.stderr)
            XCTAssertTrue(result.stdout.contains(originalHash), "Installer must consume the validated copy")
            XCTAssertTrue(result.stdout.contains("package-owner=\(asRoot ? 0 : getuid()) mode=600"))
            XCTAssertTrue(result.stdout.contains("directory-owner=\(asRoot ? 0 : getuid()) mode=700"))
            XCTAssertEqual(try String(contentsOf: package, encoding: .utf8), "replacement")
            assertStagingRemoved(result)
        }
    }

    /// Execute the production shell program, substituting only the actual system
    /// installer so these tests never install software or change receipts.
    private func run(_ package: URL, in root: URL, requiresSignature: Bool,
                     asRoot: Bool = false, installer: String) -> CommandResult {
        let fakeInstaller = root.appendingPathComponent("installer")
        do {
            try ("#!/bin/sh\nset -eu\n" + installer + "\n").write(to: fakeInstaller, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeInstaller.path)
        } catch {
            XCTFail("Fixture creation failed: \(error)")
            return (-1, "", "\(error)")
        }
        let command = ToolsInstallation.protectedInstallationCommand(package, requiresTrustedSignature: requiresSignature)
            .replacingOccurrences(of: "/usr/sbin/installer -pkg", with: "\(ToolsInstallation.shellQuote(fakeInstaller.path)) -pkg")
            .replacingOccurrences(of: "staged_package=", with: "printf 'stage=%s\\n' \"$stage\"\nstaged_package=")
        if asRoot {
            return CommandRunner.run("/usr/bin/sudo", ["-n", "/bin/sh", "-c", command], timeout: 30)
        }
        return CommandRunner.run("/bin/sh", ["-c", command], timeout: 30)
    }

    private func assertStagingRemoved(_ result: CommandResult, file: StaticString = #filePath, line: UInt = #line) {
        guard let stage = result.stdout.split(separator: "\n").first(where: { $0.hasPrefix("stage=") }) else {
            return XCTFail("No staging path: \(result.stderr)", file: file, line: line)
        }
        let path = String(stage.dropFirst("stage=".count))
        XCTAssertTrue(path.hasPrefix("/private/var/tmp/Capsomnia-Tools."), file: file, line: line)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), file: file, line: line)
    }

    private func withFixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Tools test ' \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func makePackage(in root: URL, supportedFormat: Bool) throws -> URL {
        let component = root.appendingPathComponent("component.pkg")
        let built = CommandRunner.run("/usr/bin/pkgbuild", ["--nopayload", "--identifier", "test.capsomnia.tools.staging", "--version", "1.0", component.path])
        XCTAssertEqual(built.status, 0, built.stderr)
        let xml = root.appendingPathComponent("distribution.xml")
        let marker = supportedFormat ? "<!-- \(ToolsInstallation.formatMarker) -->" : ""
        try """
        <?xml version="1.0" encoding="utf-8"?>
        <installer-gui-script minSpecVersion="2">
          \(marker)
          <title>Fixture</title>
          <choices-outline><line choice="default" /></choices-outline>
          <choice id="default"><pkg-ref id="test.capsomnia.tools.staging" /></choice>
          <pkg-ref id="test.capsomnia.tools.staging" version="1.0">component.pkg</pkg-ref>
        </installer-gui-script>
        """.write(to: xml, atomically: true, encoding: .utf8)
        let package = root.appendingPathComponent("tools ' package.pkg")
        let product = CommandRunner.run("/usr/bin/productbuild", ["--distribution", xml.path, "--package-path", root.path, package.path])
        XCTAssertEqual(product.status, 0, product.stderr)
        return package
    }
}

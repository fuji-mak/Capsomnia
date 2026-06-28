import AppKit
import CoreGraphics
import Foundation

private let helperPath = "/Library/PrivilegedHelperTools/capsomnia-pmset"
private let logPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/Capsomnia/capsomnia.log")
    .path

final class Capsomnia: NSObject, NSApplicationDelegate {
    private var lastAppliedState: Bool?
    private var eventTap: CFMachPort?
    private var pollingTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var statusItem: NSStatusItem?
    private var stateMenuItem: NSMenuItem?
    private let onImage = DotImage.make(color: .systemGreen)
    private let offImage = DotImage.make(color: NSColor(calibratedWhite: 0.58, alpha: 1.0))

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        installSignalHandlers()
        installEventTapOrFallback()
        log("start")
        applyCurrentCapsLockState(reason: "startup")
    }

    func applicationWillTerminate(_ notification: Notification) {
        log("terminate restore_off")
        _ = runHelper("off")
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 24)
        statusItem = item

        if let button = item.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.toolTip = "Capsomnia"
        }

        let menu = NSMenu()
        let stateItem = NSMenuItem(title: "Caps Lock: checking", action: nil, keyEquivalent: "")
        stateMenuItem = stateItem
        menu.addItem(stateItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        updateStatus(capsLockOn: false, helperStatus: nil)
    }

    @objc private func quit() {
        log("menu_quit")
        NSApp.terminate(nil)
    }

    private func installEventTapOrFallback() {
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            log("event_tap_unavailable using_polling_fallback")
            installPollingMonitor()
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("event_tap_ready")
        installPollingMonitor()
    }

    private func installPollingMonitor() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.applyCurrentCapsLockState(reason: "poll")
        }
    }

    fileprivate func handleFlagsChanged(_ event: CGEvent) {
        let capsLockOn = event.flags.contains(.maskAlphaShift)
        DispatchQueue.main.async { [weak self] in
            self?.apply(capsLockOn: capsLockOn, reason: "flagsChanged")
        }
    }

    fileprivate func reenableEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            log("event_tap_reenabled")
        }
    }

    private func applyCurrentCapsLockState(reason: String) {
        let flags = CGEventSource.flagsState(.hidSystemState)
        apply(capsLockOn: flags.contains(.maskAlphaShift), reason: reason)
    }

    private func apply(capsLockOn: Bool, reason: String) {
        guard lastAppliedState != capsLockOn else { return }
        lastAppliedState = capsLockOn

        let mode = capsLockOn ? "on" : "off"
        let result = runHelper(mode)
        updateStatus(capsLockOn: capsLockOn, helperStatus: result.status)
        log("\(reason) capslock=\(mode) helper_status=\(result.status) stdout=\(result.stdout) stderr=\(result.stderr)")
    }

    private func updateStatus(capsLockOn: Bool, helperStatus: Int32?) {
        let title = capsLockOn ? "Caps Lock: ON / sleep disabled" : "Caps Lock: OFF / normal sleep"
        stateMenuItem?.title = helperStatus.map { "\(title) / pmset=\($0)" } ?? title

        guard let button = statusItem?.button else { return }
        button.image = capsLockOn ? onImage : offImage
        button.toolTip = capsLockOn
            ? "Caps Lock ON: processes stay awake"
            : "Caps Lock OFF: normal sleep"
    }

    private func runHelper(_ mode: String) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath, mode]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
            return (
                process.terminationStatus,
                read(stdoutPipe.fileHandleForReading),
                read(stderrPipe.fileHandleForReading)
            )
        } catch {
            return (-1, "", "\(error)")
        }
    }

    private func read(_ handle: FileHandle) -> String {
        let data = handle.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        for signalNumber in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                self?.log("signal=\(signalNumber) restore_off")
                _ = self?.runHelper("off")
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        let url = URL(fileURLWithPath: logPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logPath),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

private enum DotImage {
    static func make(color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private nonisolated(unsafe) let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let app = Unmanaged<Capsomnia>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    switch type {
    case .flagsChanged:
        app.handleFlagsChanged(event)
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        app.reenableEventTap()
    default:
        break
    }

    return Unmanaged.passUnretained(event)
}

let app = NSApplication.shared
let delegate = Capsomnia()
app.delegate = delegate
app.run()

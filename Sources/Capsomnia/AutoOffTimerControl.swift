import AppKit

/// Utilitarian auto-off control: a large countdown readout, quick-pick preset
/// chips, and a popover-based custom hour/minute stepper. Matches the
/// landing-page LED palette.
///
/// The control owns no timing logic. It reads the live display state from
/// `displayProvider` (supplied by the app delegate) on a 1-second tick while the
/// window is visible, and reports the chosen duration through `onMinutesChange`.
final class AutoOffTimerControl: NSView {
    /// Called with the newly selected duration in minutes (`0` == no timer).
    var onMinutesChange: ((Int) -> Void)?
    /// Supplies the current readout state for the big countdown display.
    var displayProvider: (() -> AutoOffDisplayState)?
    /// Called when the Restart button is pressed.
    var onRestart: (() -> Void)?

    private(set) var minutes: Int
    /// The value used while the custom section is active; seeded from `minutes`.
    private var customMinutes: Int
    /// Whether the custom value is selected. Tracked explicitly so that stepping
    /// onto a value that happens to equal a preset does not collapse the editor.
    private var isCustom: Bool

    private let descLabel = brandLabel(size: 12, color: Brand.textDim, wraps: true)
    private let captionLabel = brandLabel(size: 11, weight: .semibold, color: Brand.textFaint)
    private let countdownLabel = NSTextField(labelWithString: "")
    private var restartButton: AutoOffStep!
    private let countdownBlock = NSView()
    private let chipsColumn = NSStackView()
    private let column = NSStackView()

    private var offChip: AutoOffChip!
    private var customChip: AutoOffChip!
    private var presetChips: [(minutes: Int, chip: AutoOffChip)] = []

    private let customPopover = NSPopover()
    private let customEditor = NSView()
    private let hoursValueLabel = AutoOffTimerControl.makeValueLabel()
    private let minutesValueLabel = AutoOffTimerControl.makeValueLabel()
    private let hoursUnitLabel = brandLabel(size: 12, weight: .medium, color: Brand.textDim)
    private let minutesUnitLabel = brandLabel(size: 12, weight: .medium, color: Brand.textDim)

    private var turnsOffInText = "Turns off in"
    private var displayTimer: Timer?

    init(minutes: Int) {
        let clamped = min(max(minutes, 0), AutoOffPreset.maxCustomMinutes)
        self.minutes = clamped
        self.customMinutes = clamped > 0 ? clamped : 45
        self.isCustom = clamped > 0 && !AutoOffPreset.isQuickPick(clamped)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
        refreshSelection()
        renderDisplay()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        displayTimer?.invalidate()
        customPopover.close()
    }

    // MARK: - Public API

    /// Update the control from an external source (e.g. Preferences).
    func setMinutes(_ newValue: Int) {
        let clamped = min(max(newValue, 0), AutoOffPreset.maxCustomMinutes)
        minutes = clamped
        if clamped > 0 {
            customMinutes = clamped
        }
        isCustom = clamped > 0 && !AutoOffPreset.isQuickPick(clamped)
        refreshSelection()
        renderDisplay()
    }

    func setStrings(
        desc: String,
        off: String,
        custom: String,
        turnsOffIn: String,
        hours: String,
        minutesUnit: String,
        restart: String
    ) {
        descLabel.stringValue = desc
        offChip.setText(off)
        customChip.setText(custom)
        for entry in presetChips {
            entry.chip.setText(AutoOffFormatter.durationLabel(minutes: entry.minutes))
        }
        turnsOffInText = turnsOffIn
        hoursUnitLabel.stringValue = hours
        minutesUnitLabel.stringValue = minutesUnit
        restartButton.setAccessibilityLabel(restart)
        restartButton.toolTip = restart
        renderDisplay()
    }

    /// Begin ticking the countdown display (call when the window becomes visible).
    func startDisplayUpdates() {
        renderDisplay()
        guard displayTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.renderDisplay()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    /// Stop ticking the countdown display (call when the window closes).
    func stopDisplayUpdates() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    /// Close transient UI when the settings page or window is dismissed.
    func dismissCustomEditor() {
        customPopover.close()
    }

    var isCustomEditorVisible: Bool {
        customPopover.isShown
    }

    // MARK: - Build

    private func build() {
        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 38, weight: .semibold)
        countdownLabel.textColor = Brand.text
        countdownLabel.alignment = .center
        countdownLabel.isBezeled = false
        countdownLabel.isEditable = false
        countdownLabel.drawsBackground = false
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.alignment = .center

        countdownBlock.translatesAutoresizingMaskIntoConstraints = false
        countdownBlock.addSubview(captionLabel)
        countdownBlock.addSubview(countdownLabel)
        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: countdownBlock.topAnchor),
            captionLabel.centerXAnchor.constraint(equalTo: countdownBlock.centerXAnchor),
            captionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: countdownBlock.leadingAnchor),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: countdownBlock.trailingAnchor),
            countdownLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 2),
            countdownLabel.centerXAnchor.constraint(equalTo: countdownBlock.centerXAnchor),
            countdownLabel.leadingAnchor.constraint(greaterThanOrEqualTo: countdownBlock.leadingAnchor),
            countdownLabel.trailingAnchor.constraint(lessThanOrEqualTo: countdownBlock.trailingAnchor),
            countdownLabel.bottomAnchor.constraint(equalTo: countdownBlock.bottomAnchor)
        ])

        restartButton = AutoOffStep(symbolName: "arrow.clockwise", accessibility: "Restart timer")
        restartButton.onClick = { [weak self] in self?.onRestart?() }
        countdownBlock.addSubview(restartButton)
        NSLayoutConstraint.activate([
            restartButton.trailingAnchor.constraint(equalTo: countdownBlock.trailingAnchor),
            restartButton.centerYAnchor.constraint(equalTo: countdownLabel.centerYAnchor)
        ])

        buildChips()
        buildCustomEditor()

        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        column.addArrangedSubview(descLabel)
        column.addArrangedSubview(countdownBlock)
        column.addArrangedSubview(chipsColumn)
        column.setCustomSpacing(16, after: descLabel)
        column.setCustomSpacing(16, after: countdownBlock)

        addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            descLabel.widthAnchor.constraint(equalTo: column.widthAnchor),
            countdownBlock.widthAnchor.constraint(equalTo: column.widthAnchor),
            chipsColumn.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
    }

    private func buildChips() {
        offChip = AutoOffChip(text: "Off")
        offChip.onClick = { [weak self] in self?.selectPreset(0) }

        customChip = AutoOffChip(text: "Custom")
        customChip.onClick = { [weak self] in self?.selectCustom() }

        var firstRow: [AutoOffChip] = [offChip]
        var secondRow: [AutoOffChip] = []
        for (index, value) in AutoOffPreset.minuteOptions.enumerated() {
            let chip = AutoOffChip(text: AutoOffFormatter.durationLabel(minutes: value))
            chip.onClick = { [weak self] in self?.selectPreset(value) }
            presetChips.append((value, chip))
            if index < 3 {
                firstRow.append(chip)
            } else {
                secondRow.append(chip)
            }
        }
        secondRow.append(customChip)

        chipsColumn.orientation = .vertical
        chipsColumn.alignment = .leading
        chipsColumn.spacing = 8
        chipsColumn.translatesAutoresizingMaskIntoConstraints = false

        let row1 = chipRow(firstRow)
        let row2 = chipRow(secondRow)
        chipsColumn.addArrangedSubview(row1)
        chipsColumn.addArrangedSubview(row2)
        row1.widthAnchor.constraint(equalTo: chipsColumn.widthAnchor).isActive = true
        row2.widthAnchor.constraint(equalTo: chipsColumn.widthAnchor).isActive = true
    }

    private func chipRow(_ chips: [AutoOffChip]) -> NSStackView {
        let row = NSStackView(views: chips)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func buildCustomEditor() {
        let hoursRow = stepperRow(
            unitLabel: hoursUnitLabel,
            valueLabel: hoursValueLabel,
            onMinus: { [weak self] in
                self?.adjustCustom(byMinutes: -AutoOffPreset.customHourStep)
            },
            onPlus: { [weak self] in
                self?.adjustCustom(byMinutes: AutoOffPreset.customHourStep)
            }
        )
        let minutesRow = stepperRow(
            unitLabel: minutesUnitLabel,
            valueLabel: minutesValueLabel,
            onMinus: { [weak self] in
                self?.adjustCustom(byMinutes: -AutoOffPreset.customMinuteStep)
            },
            onPlus: { [weak self] in
                self?.adjustCustom(byMinutes: AutoOffPreset.customMinuteStep)
            }
        )

        let stack = NSStackView(views: [hoursRow, minutesRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        customEditor.frame = NSRect(x: 0, y: 0, width: 300, height: 116)
        customEditor.wantsLayer = true
        customEditor.layer?.backgroundColor = Brand.surface.cgColor
        customEditor.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: customEditor.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: customEditor.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: customEditor.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: customEditor.bottomAnchor, constant: -16),
            hoursRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            minutesRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        let controller = NSViewController()
        controller.view = customEditor
        customPopover.contentViewController = controller
        customPopover.contentSize = customEditor.frame.size
        customPopover.behavior = .transient
        customPopover.animates = false
        customPopover.appearance = NSAppearance(named: .darkAqua)
    }

    private func stepperRow(
        unitLabel: NSTextField,
        valueLabel: NSTextField,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> NSView {
        let minus = AutoOffStep(symbolName: "minus", accessibility: "Decrease")
        minus.onClick = onMinus
        let plus = AutoOffStep(symbolName: "plus", accessibility: "Increase")
        plus.onClick = onPlus

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        let row = NSStackView(views: [unitLabel, spacer, minus, valueLabel, plus])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private static func makeValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "0")
        label.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
        label.textColor = Brand.text
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 52).isActive = true
        return label
    }

    // MARK: - Selection

    private func selectPreset(_ value: Int) {
        customPopover.close()
        let changed = minutes != value
        isCustom = false
        minutes = value
        refreshSelection()
        if changed {
            onMinutesChange?(value)
        }
        renderDisplay()
    }

    private func selectCustom() {
        isCustom = true
        let selectedMinutes = min(
            max(customMinutes, AutoOffPreset.minCustomMinutes),
            AutoOffPreset.maxCustomMinutes
        )
        let changed = minutes != selectedMinutes
        minutes = selectedMinutes
        customMinutes = minutes
        refreshSelection()
        if changed {
            onMinutesChange?(minutes)
        }
        renderDisplay()
        if customPopover.isShown {
            customPopover.close()
        } else {
            customPopover.show(
                relativeTo: customChip.bounds,
                of: customChip,
                preferredEdge: .minY
            )
        }
    }

    private func adjustCustom(byMinutes delta: Int) {
        let updated = AutoOffPreset.adjustedCustomMinutes(customMinutes, by: delta)
        guard updated != customMinutes else { return }
        customMinutes = updated
        minutes = updated
        refreshSelection()
        onMinutesChange?(updated)
        renderDisplay()
    }

    private func refreshSelection() {
        offChip.setSelected(!isCustom && minutes == 0)
        customChip.setSelected(isCustom)
        for entry in presetChips {
            entry.chip.setSelected(!isCustom && entry.minutes == minutes)
        }
        hoursValueLabel.stringValue = "\(customMinutes / 60)"
        minutesValueLabel.stringValue = String(format: "%02d", customMinutes % 60)
        restartButton.isHidden = (minutes == 0)
    }

    private func renderDisplay() {
        let state = displayProvider?() ?? .idle(minutes: minutes)
        switch state {
        case let .idle(armedMinutes):
            captionLabel.isHidden = true
            captionLabel.stringValue = ""
            countdownLabel.stringValue = AutoOffFormatter.durationLabel(minutes: armedMinutes)
            countdownLabel.textColor = armedMinutes > 0 ? Brand.text : Brand.textDim
        case .infinite:
            captionLabel.isHidden = true
            captionLabel.stringValue = ""
            countdownLabel.stringValue = "∞"
            countdownLabel.textColor = Brand.textDim
        case let .counting(remaining):
            captionLabel.isHidden = false
            captionLabel.stringValue = turnsOffInText.uppercased()
            countdownLabel.stringValue = AutoOffFormatter.countdown(remaining)
            countdownLabel.textColor = Brand.led
        }
    }
}

// MARK: - Chip

/// A selectable quick-pick pill in the auto-off control.
private final class AutoOffChip: NSView {
    private let label = NSTextField(labelWithString: "")
    private var isSelected = false
    private var isHovered = false
    var onClick: (() -> Void)?

    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        focusRingType = .exterior

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityEnabled(true)

        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = text
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6)
        ])

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        ))
        setText(text)
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    func setText(_ text: String) {
        label.stringValue = text
        setAccessibilityLabel(text)
    }

    func setSelected(_ value: Bool) {
        isSelected = value
        setAccessibilityValue(value)
        refreshAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshAppearance()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
            onClick?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func refreshAppearance() {
        if isSelected {
            layer?.backgroundColor = Brand.led.cgColor
            layer?.borderColor = Brand.led.cgColor
            label.textColor = .black
        } else {
            layer?.backgroundColor = (isHovered ? Brand.surface2 : Brand.surface).cgColor
            layer?.borderColor = (
                isHovered ? Brand.led.withAlphaComponent(0.4) : Brand.borderStrong
            ).cgColor
            label.textColor = Brand.text
        }
    }
}

// MARK: - Stepper button

/// A round +/- button used by the custom hour/minute steppers.
private final class AutoOffStep: NSView {
    private let iconView = NSImageView()
    private var isHovered = false
    var onClick: (() -> Void)?

    init(symbolName: String, accessibility: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        focusRingType = .exterior

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityEnabled(true)
        setAccessibilityLabel(accessibility)

        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibility)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        iconView.contentTintColor = Brand.led
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 36),
            heightAnchor.constraint(equalToConstant: 36),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeInActiveApp, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        ))
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshAppearance()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.charactersIgnoringModifiers == " " {
            onClick?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
    }

    override func drawFocusRingMask() {
        NSBezierPath(ovalIn: bounds).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func refreshAppearance() {
        layer?.backgroundColor = (
            isHovered ? Brand.led.withAlphaComponent(0.16) : Brand.led.withAlphaComponent(0.09)
        ).cgColor
        layer?.borderColor = (
            isHovered ? Brand.led.withAlphaComponent(0.5) : Brand.led.withAlphaComponent(0.25)
        ).cgColor
    }
}

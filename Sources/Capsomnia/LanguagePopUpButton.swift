import AppKit

/// A compact, native pop-up button for choosing one language.
final class LanguagePopUpButton: NSPopUpButton {
    var onSelect: ((String) -> Void)?

    init(items: [(title: String, value: String)], selected: String) {
        super.init(frame: .zero, pullsDown: false)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        controlSize = .small
        font = .systemFont(ofSize: 12, weight: .semibold)
        alignment = .left
        bezelStyle = .rounded
        bezelColor = Brand.surface2
        contentTintColor = Brand.text
        target = self
        action = #selector(selectionChanged)

        menu?.removeAllItems()
        for item in items {
            let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
            menuItem.representedObject = item.value
            menu?.addItem(menuItem)
        }
        setSelected(selected)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 124),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { nil }

    var selectedValue: String {
        selectedItem?.representedObject as? String ?? ""
    }

    func setSelected(_ value: String) {
        guard let item = itemArray.first(where: { $0.representedObject as? String == value }) else {
            selectItem(at: 0)
            return
        }
        select(item)
    }

    @objc private func selectionChanged() {
        onSelect?(selectedValue)
    }
}

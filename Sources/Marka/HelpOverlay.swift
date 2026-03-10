import AppKit

@MainActor
final class HelpOverlay: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        layer?.cornerRadius = 12

        let shortcuts = [
            ("j / k", "Scroll down / up"),
            ("J / K", "Scroll half page down / up"),
            ("d / u", "Scroll half page down / up"),
            ("g / G", "Go to top / bottom"),
            ("\u{2318}F", "Find in page"),
            ("\u{2318}+ / \u{2318}-", "Zoom in / out"),
            ("\u{2318}0", "Actual size"),
            ("\u{21E7}\u{2318}N", "Narrow layout"),
            ("\u{21E7}\u{2318}T", "Keep on top"),
            ("\u{21E7}\u{2318}C", "Copy as rich text"),
            ("\u{21E7}\u{2318}V", "Preview clipboard"),
            ("?", "Toggle this help"),
            ("Esc", "Close"),
        ]

        let title = NSTextField(labelWithString: "Keyboard Shortcuts")
        title.font = NSFont.boldSystemFont(ofSize: 16)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        var lastView: NSView = title
        for (key, desc) in shortcuts {
            let row = makeRow(key: key, description: desc)
            addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 4),
                row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
                row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            ])
            lastView = row
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            lastView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            widthAnchor.constraint(equalToConstant: 320),
        ])

        translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeRow(key: String, description: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let keyLabel = NSTextField(labelWithString: key)
        keyLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        keyLabel.textColor = NSColor(white: 0.9, alpha: 1)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.textColor = NSColor(white: 0.7, alpha: 1)
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(keyLabel)
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            keyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            keyLabel.widthAnchor.constraint(equalToConstant: 110),

            descLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 12),
            descLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            descLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),

            container.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    override func mouseDown(with event: NSEvent) {
        Self.dismiss(from: window)
    }

    static func toggle(in window: NSWindow) {
        if findExisting(in: window) != nil {
            dismiss(from: window)
        } else {
            show(in: window)
        }
    }

    static func show(in window: NSWindow) {
        guard let contentView = window.contentView else { return }
        if findExisting(in: window) != nil { return }

        let overlay = HelpOverlay()
        contentView.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    static func dismiss(from window: NSWindow?) {
        findExisting(in: window)?.removeFromSuperview()
    }

    private static func findExisting(in window: NSWindow?) -> HelpOverlay? {
        window?.contentView?.subviews.first(where: { $0 is HelpOverlay }) as? HelpOverlay
    }
}

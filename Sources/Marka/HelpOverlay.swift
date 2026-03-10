import AppKit

/// Displays keyboard shortcuts as a floating panel attached to the parent window.
/// Uses NSPanel instead of a subview to avoid NSHostingView layout issues.
@MainActor
enum HelpOverlay {
    private static var panel: NSPanel?

    static func toggle(in window: NSWindow) {
        if panel != nil {
            dismiss(from: window)
        } else {
            show(in: window)
        }
    }

    static func show(in window: NSWindow) {
        guard panel == nil else { return }

        let shortcuts = [
            ("j / k", "Scroll down / up"),
            ("J / K", "Scroll half page down / up"),
            ("d / u", "Scroll half page down / up"),
            ("g / G", "Go to top / bottom"),
            (", / .", "Previous / next heading"),
            ("< / >", "Previous / next h1/h2"),
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

        let width: CGFloat = 320
        let padding: CGFloat = 20
        let rowHeight: CGFloat = 22
        let rowSpacing: CGFloat = 4
        let keyColWidth: CGFloat = 110
        let titleHeight: CGFloat = 22

        let totalHeight = padding + titleHeight + CGFloat(shortcuts.count) * (rowHeight + rowSpacing) + padding

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        contentView.layer?.cornerRadius = 12

        // Title
        let title = NSTextField(labelWithString: "Keyboard Shortcuts")
        title.font = NSFont.boldSystemFont(ofSize: 16)
        title.textColor = .white
        title.isBezeled = false
        title.drawsBackground = false
        title.isEditable = false
        title.isSelectable = false
        title.sizeToFit()
        title.frame.origin = NSPoint(
            x: (width - title.frame.width) / 2,
            y: totalHeight - padding - titleHeight
        )
        contentView.addSubview(title)

        // Rows (top to bottom, AppKit y goes up)
        var y = title.frame.origin.y - rowSpacing - rowHeight
        for (key, desc) in shortcuts {
            let keyLabel = NSTextField(labelWithString: key)
            keyLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            keyLabel.textColor = NSColor(white: 0.9, alpha: 1)
            keyLabel.isBezeled = false
            keyLabel.drawsBackground = false
            keyLabel.isEditable = false
            keyLabel.isSelectable = false
            keyLabel.frame = NSRect(x: padding, y: y, width: keyColWidth, height: rowHeight)

            let descLabel = NSTextField(labelWithString: desc)
            descLabel.font = NSFont.systemFont(ofSize: 13)
            descLabel.textColor = NSColor(white: 0.7, alpha: 1)
            descLabel.isBezeled = false
            descLabel.drawsBackground = false
            descLabel.isEditable = false
            descLabel.isSelectable = false
            descLabel.frame = NSRect(
                x: padding + keyColWidth + 12,
                y: y,
                width: width - padding * 2 - keyColWidth - 12,
                height: rowHeight
            )

            contentView.addSubview(keyLabel)
            contentView.addSubview(descLabel)
            y -= (rowHeight + rowSpacing)
        }

        // Position centered over the parent window
        let parentFrame = window.frame
        let panelX = parentFrame.origin.x + (parentFrame.width - width) / 2
        let panelY = parentFrame.origin.y + (parentFrame.height - totalHeight) / 2
        let panelFrame = NSRect(x: panelX, y: panelY, width: width, height: totalHeight)

        let p = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.contentView = contentView
        p.isMovableByWindowBackground = false

        window.addChildWindow(p, ordered: .above)
        p.orderFront(nil)
        panel = p
    }

    static func dismiss(from window: NSWindow?) {
        guard let p = panel else { return }
        window?.removeChildWindow(p)
        p.orderOut(nil)
        panel = nil
    }
}

import AppKit
import WebKit

@MainActor
final class MenuBarBuilder: NSObject, NSMenuItemValidation {
    private let evaluateJS: (String) -> Void

    init(evaluateJS: @escaping (String) -> Void) {
        self.evaluateJS = evaluateJS
        super.init()
    }

    func buildMenuBar() -> (mainMenu: NSMenu, windowMenu: NSMenu) {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Marka", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Marka", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (for copy support)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let findItem = NSMenuItem(title: "Find\u{2026}", action: #selector(showFind), keyEquivalent: "f")
        findItem.target = self
        editMenu.addItem(findItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let keepOnTopItem = NSMenuItem(title: "Keep on Top", action: #selector(toggleKeepOnTop), keyEquivalent: "t")
        keepOnTopItem.keyEquivalentModifierMask = [.command, .shift]
        keepOnTopItem.target = self
        viewMenu.addItem(keepOnTopItem)
        viewMenu.addItem(.separator())
        let actualSizeItem = NSMenuItem(title: "Actual Size", action: #selector(actualSize), keyEquivalent: "0")
        actualSizeItem.target = self
        viewMenu.addItem(actualSizeItem)
        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(zoomIn), keyEquivalent: "+")
        zoomInItem.target = self
        viewMenu.addItem(zoomInItem)
        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-")
        zoomOutItem.target = self
        viewMenu.addItem(zoomOutItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        return (mainMenu, windowMenu)
    }

    // MARK: - Actions

    @objc private func showFind() {
        evaluateJS("window.markaOpenFind()")
    }

    @objc private func toggleKeepOnTop() {
        guard let window = NSApp.keyWindow else { return }
        if window.level == .floating {
            window.level = .normal
        } else {
            window.level = .floating
        }
    }

    @objc private func actualSize() {
        evaluateJS("document.body.style.zoom = '1'")
    }

    @objc private func zoomIn() {
        evaluateJS("""
            var z = parseFloat(document.body.style.zoom || '1');
            document.body.style.zoom = String(Math.min(z + 0.1, 3));
        """)
    }

    @objc private func zoomOut() {
        evaluateJS("""
            var z = parseFloat(document.body.style.zoom || '1');
            document.body.style.zoom = String(Math.max(z - 0.1, 0.3));
        """)
    }

    // MARK: - Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleKeepOnTop) {
            menuItem.state = NSApp.keyWindow?.level == .floating ? .on : .off
            return NSApp.keyWindow != nil
        }
        return true
    }
}

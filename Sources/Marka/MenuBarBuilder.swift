import AppKit
import WebKit

@MainActor
final class MenuBarBuilder: NSObject, NSMenuItemValidation {
    private let evaluateJS: (String) -> Void
    private let evaluateJSWithResult: (String, @escaping (String?) -> Void) -> Void
    private let openDocument: (IPCPayload) -> Void
    private let evaluateJSAllWindows: (String) -> Void

    init(
        evaluateJS: @escaping (String) -> Void,
        evaluateJSWithResult: @escaping (String, @escaping (String?) -> Void) -> Void,
        openDocument: @escaping (IPCPayload) -> Void,
        evaluateJSAllWindows: @escaping (String) -> Void
    ) {
        self.evaluateJS = evaluateJS
        self.evaluateJSWithResult = evaluateJSWithResult
        self.openDocument = openDocument
        self.evaluateJSAllWindows = evaluateJSAllWindows
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

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let previewClipboardItem = NSMenuItem(title: "Preview Clipboard", action: #selector(previewClipboard), keyEquivalent: "V")
        previewClipboardItem.keyEquivalentModifierMask = [.command, .shift]
        previewClipboardItem.target = self
        fileMenu.addItem(previewClipboardItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu (for copy support)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let copyRichTextItem = NSMenuItem(title: "Copy as Rich Text", action: #selector(copyAsRichText), keyEquivalent: "C")
        copyRichTextItem.keyEquivalentModifierMask = [.command, .shift]
        copyRichTextItem.target = self
        editMenu.addItem(copyRichTextItem)
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
        let narrowLayoutItem = NSMenuItem(title: "Narrow Layout", action: #selector(toggleNarrowLayout), keyEquivalent: "N")
        narrowLayoutItem.keyEquivalentModifierMask = [.command, .shift]
        narrowLayoutItem.target = self
        viewMenu.addItem(narrowLayoutItem)
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

    @objc private func copyAsRichText() {
        evaluateJSWithResult("window.markaGetContentHTML()") { html in
            guard let html = html, !html.isEmpty else { return }
            guard let data = html.data(using: .utf8),
                  let attrStr = NSAttributedString(html: data, documentAttributes: nil) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([attrStr])
        }
    }

    @objc private func previewClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep()
            return
        }
        let tempPath = NSTemporaryDirectory() + "marka-clipboard-\(ProcessInfo.processInfo.processIdentifier).md"
        do {
            try text.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
            return
        }
        openDocument(IPCPayload(path: tempPath, isTemp: true, title: "Clipboard", baseURL: nil))
    }

    @objc private func toggleNarrowLayout() {
        let current = UserDefaults.standard.bool(forKey: "narrowLayout")
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: "narrowLayout")
        evaluateJSAllWindows("window.markaSetNarrowLayout(\(newValue))")
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
        if menuItem.action == #selector(copyAsRichText) {
            return NSApp.keyWindow != nil
        }
        if menuItem.action == #selector(toggleNarrowLayout) {
            menuItem.state = UserDefaults.standard.bool(forKey: "narrowLayout") ? .on : .off
            return true
        }
        return true
    }
}

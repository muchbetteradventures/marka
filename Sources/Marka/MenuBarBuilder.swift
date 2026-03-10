import AppKit

@MainActor
final class MenuBarBuilder: NSObject, NSMenuItemValidation {
    private let showFind: () -> Void
    private let copyRichText: () -> Void
    private let zoomIn: () -> Void
    private let zoomOut: () -> Void
    private let actualSize: () -> Void
    private let toggleNarrowLayout: () -> Void
    private let openDocument: (IPCPayload) -> Void

    init(
        showFind: @escaping () -> Void,
        copyRichText: @escaping () -> Void,
        zoomIn: @escaping () -> Void,
        zoomOut: @escaping () -> Void,
        actualSize: @escaping () -> Void,
        toggleNarrowLayout: @escaping () -> Void,
        openDocument: @escaping (IPCPayload) -> Void
    ) {
        self.showFind = showFind
        self.copyRichText = copyRichText
        self.zoomIn = zoomIn
        self.zoomOut = zoomOut
        self.actualSize = actualSize
        self.toggleNarrowLayout = toggleNarrowLayout
        self.openDocument = openDocument
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

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let copyRichTextItem = NSMenuItem(title: "Copy as Rich Text", action: #selector(doCopyRichText), keyEquivalent: "C")
        copyRichTextItem.keyEquivalentModifierMask = [.command, .shift]
        copyRichTextItem.target = self
        editMenu.addItem(copyRichTextItem)
        editMenu.addItem(.separator())
        let findItem = NSMenuItem(title: "Find\u{2026}", action: #selector(doShowFind), keyEquivalent: "f")
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
        let narrowLayoutItem = NSMenuItem(title: "Narrow Layout", action: #selector(doToggleNarrowLayout), keyEquivalent: "N")
        narrowLayoutItem.keyEquivalentModifierMask = [.command, .shift]
        narrowLayoutItem.target = self
        viewMenu.addItem(narrowLayoutItem)
        viewMenu.addItem(.separator())
        let actualSizeItem = NSMenuItem(title: "Actual Size", action: #selector(doActualSize), keyEquivalent: "0")
        actualSizeItem.target = self
        viewMenu.addItem(actualSizeItem)
        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(doZoomIn), keyEquivalent: "+")
        zoomInItem.target = self
        viewMenu.addItem(zoomInItem)
        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(doZoomOut), keyEquivalent: "-")
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

    @objc private func doShowFind() { showFind() }
    @objc private func doCopyRichText() { copyRichText() }
    @objc private func doZoomIn() { zoomIn() }
    @objc private func doZoomOut() { zoomOut() }
    @objc private func doActualSize() { actualSize() }
    @objc private func doToggleNarrowLayout() { toggleNarrowLayout() }

    @objc private func toggleKeepOnTop() {
        guard let window = NSApp.keyWindow else { return }
        if window.level == .floating {
            window.level = .normal
        } else {
            window.level = .floating
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
        openDocument(IPCPayload(path: tempPath, isTemp: true, title: "Clipboard", baseURL: nil, isTextBundle: false, bundlePath: nil, extractedPath: nil))
    }

    // MARK: - Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleKeepOnTop) {
            menuItem.state = NSApp.keyWindow?.level == .floating ? .on : .off
            return NSApp.keyWindow != nil
        }
        if menuItem.action == #selector(doCopyRichText) {
            return NSApp.keyWindow != nil
        }
        if menuItem.action == #selector(doToggleNarrowLayout) {
            menuItem.state = UserDefaults.standard.bool(forKey: "narrowLayout") ? .on : .off
            return true
        }
        return true
    }
}

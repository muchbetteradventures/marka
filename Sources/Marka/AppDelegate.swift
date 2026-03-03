import AppKit
import SwiftUI
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    private var windowInfos: [(window: NSWindow, document: MarkdownDocument, watcher: FileWatcher?, tempPath: String?)] = []
    private let ipcServer = IPCServer()
    private let initialDocument: IPCPayload

    init(initialDocument: IPCPayload) {
        self.initialDocument = initialDocument
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        // Start IPC server for subsequent invocations
        ipcServer.onOpenDocument = { [weak self] payload in
            self?.openDocument(payload: payload)
            NSApp.activate(ignoringOtherApps: true)
        }
        ipcServer.start()

        // Open the initial document
        openDocument(payload: initialDocument)

        NSApp.activate(ignoringOtherApps: true)
    }

    func openDocument(payload: IPCPayload) {
        let document = MarkdownDocument()
        let url = URL(fileURLWithPath: payload.path)

        if let content = try? String(contentsOf: url, encoding: .utf8) {
            document.markdown = content
        }
        document.title = payload.title
        if let base = payload.baseURL {
            document.baseURL = URL(string: base)
        }

        let contentView = ContentView(document: document)
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = document.title
        window.contentView = hostingView
        window.delegate = self
        window.center()

        // Cascade from the last opened window
        if let lastWindow = windowInfos.last?.window {
            let origin = lastWindow.cascadeTopLeft(from: .zero)
            window.cascadeTopLeft(from: origin)
        }

        window.makeKeyAndOrderFront(nil)

        // Start file watcher for non-temp files
        var watcher: FileWatcher?
        if !payload.isTemp {
            let fw = FileWatcher(path: payload.path) { newContent in
                document.markdown = newContent
            }
            fw.start()
            watcher = fw
        }

        windowInfos.append((
            window: window,
            document: document,
            watcher: watcher,
            tempPath: payload.isTemp ? payload.path : nil
        ))
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              let index = windowInfos.firstIndex(where: { $0.window === closingWindow }) else {
            return
        }

        let info = windowInfos[index]
        info.watcher?.stop()

        // Clean up temp file for this window
        if let tempPath = info.tempPath {
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        windowInfos.remove(at: index)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
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
        editMenu.addItem(withTitle: "Find\u{2026}", action: #selector(showFind), keyEquivalent: "f")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let keepOnTopItem = NSMenuItem(title: "Keep on Top", action: #selector(toggleKeepOnTop), keyEquivalent: "t")
        keepOnTopItem.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(keepOnTopItem)
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(actualSize), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomIn), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - Find

    @objc private func showFind() {
        evaluateJS("window.markaOpenFind()")
    }

    // MARK: - Keep on Top

    @objc private func toggleKeepOnTop() {
        guard let window = NSApp.keyWindow else { return }
        if window.level == .floating {
            window.level = .normal
        } else {
            window.level = .floating
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleKeepOnTop) {
            menuItem.state = NSApp.keyWindow?.level == .floating ? .on : .off
            return NSApp.keyWindow != nil
        }
        return true
    }

    // MARK: - Zoom (targets key window)

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

    private func evaluateJS(_ js: String) {
        guard let keyWindow = NSApp.keyWindow,
              let hostingView = keyWindow.contentView,
              let webView = findWebView(in: hostingView) else { return }
        webView.evaluateJavaScript(js)
    }

    private func findWebView(in view: NSView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for subview in view.subviews {
            if let wv = findWebView(in: subview) { return wv }
        }
        return nil
    }
}

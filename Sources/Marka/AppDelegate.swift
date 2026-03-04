import AppKit
import SwiftUI
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windowInfos: [(window: NSWindow, document: MarkdownDocument, watcher: FileWatcher?, webView: WKWebView?, tempPath: String?)] = []
    private let ipcServer = IPCServer()
    private let initialDocument: IPCPayload
    private var menuBarBuilder: MenuBarBuilder!

    init(initialDocument: IPCPayload) {
        self.initialDocument = initialDocument
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarBuilder = MenuBarBuilder(evaluateJS: { [weak self] js in
            self?.evaluateJS(js)
        })
        let menus = menuBarBuilder.buildMenuBar()
        NSApp.mainMenu = menus.mainMenu
        NSApp.windowsMenu = menus.windowMenu

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
            webView: nil,
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

    // MARK: - JS evaluation with cached WebView lookup

    private func evaluateJS(_ js: String) {
        guard let keyWindow = NSApp.keyWindow,
              let index = windowInfos.firstIndex(where: { $0.window === keyWindow }) else { return }

        // Use cached WebView if available, otherwise find and cache it
        if let webView = windowInfos[index].webView {
            webView.evaluateJavaScript(js)
        } else if let hostingView = keyWindow.contentView,
                  let webView = findWebView(in: hostingView) {
            windowInfos[index].webView = webView
            webView.evaluateJavaScript(js)
        }
    }

    private func findWebView(in view: NSView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for subview in view.subviews {
            if let wv = findWebView(in: subview) { return wv }
        }
        return nil
    }
}

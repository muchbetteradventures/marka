import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windowInfos: [(window: NSWindow, document: MarkdownDocument, watcher: FileWatcher?, webView: WKWebView?, tempPath: String?, extractedPath: String?)] = []
    private let ipcServer = IPCServer()
    private let initialDocument: IPCPayload?
    private var menuBarBuilder: MenuBarBuilder!

    init(initialDocument: IPCPayload? = nil) {
        self.initialDocument = initialDocument
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarBuilder = MenuBarBuilder(
            evaluateJS: { [weak self] js in
                self?.evaluateJS(js)
            },
            evaluateJSWithResult: { [weak self] js, handler in
                self?.evaluateJSWithResult(js, handler: handler)
            },
            openDocument: { [weak self] payload in
                self?.openDocument(payload: payload)
            },
            evaluateJSAllWindows: { [weak self] js in
                self?.evaluateJSAllWindows(js)
            }
        )
        let menus = menuBarBuilder.buildMenuBar()
        NSApp.mainMenu = menus.mainMenu
        NSApp.windowsMenu = menus.windowMenu

        // Start IPC server for subsequent invocations
        ipcServer.onOpenDocument = { [weak self] payload in
            self?.openDocument(payload: payload)
            NSApp.activate(ignoringOtherApps: true)
        }
        ipcServer.start()

        // Open the initial document, or show file picker
        if let initialDocument {
            openDocument(payload: initialDocument)
        } else {
            showOpenDialog()
        }

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
            tempPath: payload.isTemp ? payload.path : nil,
            extractedPath: payload.extractedPath
        ))
    }

    // MARK: - Open Dialog

    func showOpenDialog() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File"
        panel.allowedContentTypes = [
            .init(filenameExtension: "md")!,
            .init(filenameExtension: "markdown")!,
            .init(filenameExtension: "textbundle")!,
            .init(filenameExtension: "textpack")!,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true  // for .textbundle packages

        guard panel.runModal() == .OK, let url = panel.url else {
            // User cancelled. If no windows are open, quit.
            if windowInfos.isEmpty {
                NSApp.terminate(nil)
            }
            return
        }

        let path = url.path

        if TextBundleHandler.isTextBundle(path: path) {
            do {
                let bundle = try TextBundleHandler.load(path: path)
                let payload = IPCPayload(
                    path: bundle.markdownFilePath,
                    isTemp: bundle.isTextPack,
                    title: bundle.title,
                    baseURL: (bundle.assetsPath ?? URL(fileURLWithPath: bundle.markdownFilePath).deletingLastPathComponent()).absoluteString,
                    isTextBundle: true,
                    bundlePath: bundle.bundlePath,
                    extractedPath: bundle.extractedPath
                )
                openDocument(payload: payload)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not open file"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        } else {
            let payload = IPCPayload(
                path: path,
                isTemp: false,
                title: url.lastPathComponent,
                baseURL: url.deletingLastPathComponent().absoluteString,
                isTextBundle: false,
                bundlePath: nil,
                extractedPath: nil
            )
            openDocument(payload: payload)
        }
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

        // Clean up extracted textpack directory
        if let extractedPath = info.extractedPath {
            try? FileManager.default.removeItem(atPath: extractedPath)
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

    private func evaluateJSWithResult(_ js: String, handler: @escaping (String?) -> Void) {
        guard let keyWindow = NSApp.keyWindow,
              let index = windowInfos.firstIndex(where: { $0.window === keyWindow }) else {
            handler(nil)
            return
        }

        let webView: WKWebView?
        if let cached = windowInfos[index].webView {
            webView = cached
        } else if let hostingView = keyWindow.contentView,
                  let found = findWebView(in: hostingView) {
            windowInfos[index].webView = found
            webView = found
        } else {
            webView = nil
        }

        guard let wv = webView else {
            handler(nil)
            return
        }

        wv.evaluateJavaScript(js) { result, _ in
            handler(result as? String)
        }
    }

    private func evaluateJSAllWindows(_ js: String) {
        for i in windowInfos.indices {
            if let webView = windowInfos[i].webView {
                webView.evaluateJavaScript(js)
            } else if let hostingView = windowInfos[i].window.contentView,
                      let webView = findWebView(in: hostingView) {
                windowInfos[i].webView = webView
                webView.evaluateJavaScript(js)
            }
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

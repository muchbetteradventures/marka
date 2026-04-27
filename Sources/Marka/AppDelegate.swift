import AppKit
import MarkdownParser
import MarkdownView
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windowInfos: [(window: NSWindow, document: MarkdownDocument, watcher: FileWatcher?, tempPath: String?, extractedPath: String?, filePath: String?)] = []
    private let ipcServer = IPCServer()
    private let initialDocument: IPCPayload?
    private let openAsQLPreview: Bool
    private var menuBarBuilder: MenuBarBuilder!
    private var fileWasOpenedViaDelegate = false

    init(initialDocument: IPCPayload? = nil, openAsQLPreview: Bool = false) {
        self.initialDocument = initialDocument
        self.openAsQLPreview = openAsQLPreview
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarBuilder = MenuBarBuilder(
            showFind: { [weak self] in self?.showFind() },
            copyRichText: { [weak self] in self?.copyRichText() },
            zoomIn: { [weak self] in self?.adjustZoom(delta: 0.1) },
            zoomOut: { [weak self] in self?.adjustZoom(delta: -0.1) },
            actualSize: { [weak self] in self?.resetZoom() },
            toggleNarrowLayout: { [weak self] in self?.toggleNarrowLayout() },
            toggleOpenInTab: { [weak self] in self?.toggleOpenInTab() },
            openDocument: { [weak self] payload in
                self?.openDocument(payload: payload)
            },
            showOpenDialog: { [weak self] in
                self?.showOpenDialog()
            }
        )
        let menus = menuBarBuilder.buildMenuBar()
        NSApp.mainMenu = menus.mainMenu
        NSApp.windowsMenu = menus.windowMenu

        ipcServer.onOpenDocument = { [weak self] payload in
            self?.openDocument(payload: payload)
            NSApp.activate(ignoringOtherApps: true)
        }
        ipcServer.start()

        if let initialDocument {
            if openAsQLPreview {
                let url = URL(fileURLWithPath: initialDocument.path)
                if let markdown = try? String(contentsOf: url, encoding: .utf8) {
                    let baseURL = initialDocument.baseURL.flatMap { URL(string: $0) ?? URL(fileURLWithPath: $0) }
                    QLPreviewWindow.show(markdown: markdown, title: initialDocument.title, baseURL: baseURL)
                }
            } else {
                openDocument(payload: initialDocument)
            }
        } else {
            // Defer so that application(_:openFile:) can fire first (e.g. double-click in Finder).
            // If a file was already handled by the time this runs, skip the dialog.
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.fileWasOpenedViaDelegate else { return }
                self.showOpenDialog()
            }
        }

        KeyboardScrollHandler.shared.install()

        NSApp.activate(ignoringOtherApps: true)
    }

    func openDocument(payload: IPCPayload) {
        // Canonical path used for deduplication (nil for temp/clipboard files)
        let canonicalPath: String?
        if payload.isTemp {
            canonicalPath = nil
        } else if payload.isTextBundle, let bundlePath = payload.bundlePath {
            canonicalPath = bundlePath
        } else {
            canonicalPath = payload.path
        }

        // If already open, focus the existing window instead of creating a new one
        if let cp = canonicalPath, let existing = windowInfos.first(where: { $0.filePath == cp }) {
            existing.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Track in recent files (skip temp files like clipboard previews)
        if !payload.isTemp {
            RecentFiles.shared.add(payload)
        }

        let document = MarkdownDocument()
        let url = URL(fileURLWithPath: payload.path)

        if let content = try? String(contentsOf: url, encoding: .utf8) {
            document.markdown = content
        }
        document.title = payload.title
        if let base = payload.baseURL {
            // URL(string:) can silently return nil for file URLs with unencoded characters.
            // Fall back to URL(fileURLWithPath:) for any string that looks like a path.
            document.baseURL = URL(string: base) ?? URL(fileURLWithPath: base)
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

        let openInTab = UserDefaults.standard.bool(forKey: "openInTab")
        if openInTab, let existingWindow = windowInfos.last?.window {
            window.tabbingIdentifier = "marka.main"
            existingWindow.tabbingIdentifier = "marka.main"
            existingWindow.addTabbedWindow(window, ordered: .above)
        } else if let lastWindow = windowInfos.last?.window {
            let origin = lastWindow.cascadeTopLeft(from: .zero)
            window.cascadeTopLeft(from: origin)
        }

        window.makeKeyAndOrderFront(nil)

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
            tempPath: payload.isTemp ? payload.path : nil,
            extractedPath: payload.extractedPath,
            filePath: canonicalPath
        ))
    }

    // MARK: - Open Dialog

    func showOpenDialog() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File"
        var contentTypes: [UTType] = [
            .init(filenameExtension: "md")!,
            .init(filenameExtension: "markdown")!,
            .init(filenameExtension: "textpack")!,
        ]
        if let textBundleType = UTType("org.textbundle.package") {
            contentTypes.append(textBundleType)
        }
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let path = url.path

        if TextBundleHandler.isTextBundle(path: path) {
            do {
                let bundle = try TextBundleHandler.load(path: path)
                let payload = IPCPayload(
                    path: bundle.markdownFilePath,
                    isTemp: bundle.isTextPack,
                    title: bundle.title,
                    baseURL: URL(fileURLWithPath: bundle.markdownFilePath).deletingLastPathComponent().absoluteString,
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

        if let tempPath = info.tempPath {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
        if let extractedPath = info.extractedPath {
            try? FileManager.default.removeItem(atPath: extractedPath)
        }

        windowInfos.remove(at: index)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showOpenDialog()
        }
        return true
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        fileWasOpenedViaDelegate = true
        // Skip if we were launched with a file argument (already opened via initialDocument)
        // or if we're in QL preview mode. Either way, opening a second window is wrong.
        guard initialDocument == nil, !openAsQLPreview else { return true }
        openFromPath(filename)
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        fileWasOpenedViaDelegate = true
        guard initialDocument == nil, !openAsQLPreview else { return }
        for filename in filenames {
            openFromPath(filename)
        }
    }

    private func openFromPath(_ path: String) {
        if TextBundleHandler.isTextBundle(path: path) {
            guard let bundle = try? TextBundleHandler.load(path: path) else { return }
            let payload = IPCPayload(
                path: bundle.markdownFilePath,
                isTemp: bundle.isTextPack,
                title: bundle.title,
                baseURL: URL(fileURLWithPath: bundle.markdownFilePath).deletingLastPathComponent().absoluteString,
                isTextBundle: true,
                bundlePath: bundle.bundlePath,
                extractedPath: bundle.extractedPath
            )
            openDocument(payload: payload)
        } else {
            let url = URL(fileURLWithPath: path)
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

    // MARK: - Native actions

    static var coordinatorRegistry: [ObjectIdentifier: MarkdownNativeView.Coordinator] = [:]

    func coordinatorForKeyWindow() -> (MarkdownNativeView.Coordinator, MarkdownTextView, NSScrollView)? {
        guard let keyWindow = NSApp.keyWindow,
              let hostingView = keyWindow.contentView else { return nil }
        return findScrollViewWithMarkdown(in: hostingView)
    }

    private func findScrollViewWithMarkdown(in view: NSView) -> (MarkdownNativeView.Coordinator, MarkdownTextView, NSScrollView)? {
        if let scrollView = view as? NSScrollView,
           let markdownTextView = scrollView.documentView as? MarkdownTextView {
            // Find coordinator from registry
            let id = ObjectIdentifier(markdownTextView)
            if let coordinator = Self.coordinatorRegistry[id] {
                return (coordinator, markdownTextView, scrollView)
            }
        }
        for subview in view.subviews {
            if let result = findScrollViewWithMarkdown(in: subview) {
                return result
            }
        }
        return nil
    }

    private func showFind() {
        guard let (coordinator, markdownTextView, scrollView) = coordinatorForKeyWindow() else { return }
        // Toggle find bar
        if let keyWindow = NSApp.keyWindow {
            FindBarController.toggle(in: keyWindow, markdownTextView: markdownTextView, scrollView: scrollView)
        }
    }

    private func copyRichText() {
        guard let (_, markdownTextView, _) = coordinatorForKeyWindow() else { return }

        let attrStr: NSAttributedString
        if let range = markdownTextView.textView.selectionRange, range.length > 0 {
            attrStr = markdownTextView.textView.attributedText.attributedSubstring(from: range)
        } else {
            attrStr = markdownTextView.textView.attributedText
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([attrStr])
    }

    private func adjustZoom(delta: CGFloat) {
        guard let (coordinator, markdownTextView, scrollView) = coordinatorForKeyWindow() else { return }
        coordinator.zoomLevel = max(0.5, min(3.0, coordinator.zoomLevel + delta))
        rerender(coordinator: coordinator, markdownTextView: markdownTextView, scrollView: scrollView)
    }

    private func resetZoom() {
        guard let (coordinator, markdownTextView, scrollView) = coordinatorForKeyWindow() else { return }
        coordinator.zoomLevel = 1.0
        rerender(coordinator: coordinator, markdownTextView: markdownTextView, scrollView: scrollView)
    }

    private func toggleOpenInTab() {
        let newValue = !UserDefaults.standard.bool(forKey: "openInTab")
        UserDefaults.standard.set(newValue, forKey: "openInTab")
    }

    private func toggleNarrowLayout() {
        let current = UserDefaults.standard.bool(forKey: "narrowLayout")
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: "narrowLayout")

        // Apply to all windows
        for info in windowInfos {
            guard let hostingView = info.window.contentView,
                  let (coordinator, mtv, sv) = findScrollViewWithMarkdown(in: hostingView) else { continue }
            coordinator.narrowLayout = newValue
            MarkdownNativeView.relayout(markdownTextView: mtv, scrollView: sv, coordinator: coordinator)
        }
    }

    private func rerender(coordinator: MarkdownNativeView.Coordinator, markdownTextView: MarkdownTextView, scrollView: NSScrollView) {
        let isDark = scrollView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = MarkdownGitHubTheme.theme(dark: isDark)
        let scaledTheme = coordinator.applyZoom(to: theme)

        // Re-parse and re-render is needed because theme changed
        let body = FrontmatterParser.body(from: coordinator.lastMarkdown)
        let parser = MarkdownParser()
        let result = parser.parse(body)
        let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: scaledTheme)
        content.loadedImages = ImageLoader.loadImages(from: body, baseURL: coordinator.baseURL)
        let scrollWidth = scrollView.contentView.bounds.width
        var cw = scrollWidth - (coordinator.padding * 2)
        if coordinator.narrowLayout { cw = min(cw, 980) }
        content.contentWidth = cw
        markdownTextView.theme = scaledTheme
        markdownTextView.setMarkdownManually(content)
        MarkdownNativeView.relayout(markdownTextView: markdownTextView, scrollView: scrollView, coordinator: coordinator)
    }
}

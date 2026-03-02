import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    let document: MarkdownDocument

    init(document: MarkdownDocument) {
        self.document = document
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1800, height: 900)
        let windowWidth = floor(screenFrame.width / 2)
        let windowHeight = screenFrame.height

        let configs: [(title: String, view: AnyView)] = [
            ("Textual", AnyView(TextualContentView(document: document))),
            ("MarkdownView", AnyView(MarkdownViewContentView(document: document)))
        ]

        for (index, config) in configs.enumerated() {
            let hostingView = NSHostingView(rootView: config.view)

            let window = NSWindow(
                contentRect: NSRect(
                    x: screenFrame.minX + CGFloat(index) * windowWidth,
                    y: screenFrame.minY,
                    width: windowWidth,
                    height: windowHeight
                ),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "\(document.title) — \(config.title)"
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        setupMenuBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Markie", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Markie", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}

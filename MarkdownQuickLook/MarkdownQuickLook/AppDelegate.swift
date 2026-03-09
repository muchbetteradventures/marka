import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Markdown QuickLook"
        window.center()

        let textView = NSTextView(frame: NSRect(x: 20, y: 20, width: 440, height: 260))
        textView.isEditable = false
        textView.string = """
        Markdown QuickLook Extension

        This app provides QuickLook previews for:
        • Markdown files (.md, .markdown)
        • TextBundle packages (.textbundle)
        • TextPack archives (.textpack)

        The extension is automatically active when you use
        QuickLook (press Space) on any supported file in Finder.

        To enable the extension:
        1. Go to System Preferences → Extensions
        2. Select Quick Look
        3. Enable "Markdown Preview"
        """
        textView.font = NSFont.systemFont(ofSize: 13)

        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

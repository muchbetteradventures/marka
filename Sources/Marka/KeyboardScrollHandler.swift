import AppKit
import MarkdownView

/// Monitors key events for vim-style scrolling and help overlay.
/// Installed as a local event monitor so it works regardless of first responder.
@MainActor
final class KeyboardScrollHandler {
    static let shared = KeyboardScrollHandler()
    private var monitor: Any?

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyDown(event) == true {
                return nil // consume the event
            }
            return event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Don't intercept if a text field is first responder (e.g. find bar)
        if let responder = NSApp.keyWindow?.firstResponder,
           responder is NSTextView || responder is NSTextField {
            // Allow Escape to close find bar
            if event.keyCode == 53 {
                FindBarController.dismiss(from: NSApp.keyWindow)
                return true
            }
            return false
        }

        guard let scrollView = findScrollView() else { return false }
        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height

        switch event.charactersIgnoringModifiers {
        case "j":
            scroll(clipView, by: 80)
            return true
        case "k":
            scroll(clipView, by: -80)
            return true
        case "J":
            scroll(clipView, by: visibleHeight * 0.5)
            return true
        case "K":
            scroll(clipView, by: -visibleHeight * 0.5)
            return true
        case "d":
            scroll(clipView, by: visibleHeight * 0.5)
            return true
        case "u":
            scroll(clipView, by: -visibleHeight * 0.5)
            return true
        case "g":
            scrollToTop(clipView)
            return true
        case "G":
            scrollToBottom(clipView, scrollView: scrollView)
            return true
        case "?":
            toggleHelp()
            return true
        default:
            // Escape closes help
            if event.keyCode == 53 {
                HelpOverlay.dismiss(from: NSApp.keyWindow)
                return true
            }
            return false
        }
    }

    private func findScrollView() -> NSScrollView? {
        guard let contentView = NSApp.keyWindow?.contentView else { return nil }
        return findScrollViewRecursive(in: contentView)
    }

    private func findScrollViewRecursive(in view: NSView) -> NSScrollView? {
        if let sv = view as? NSScrollView, sv.documentView is MarkdownTextView {
            return sv
        }
        for subview in view.subviews {
            if let sv = findScrollViewRecursive(in: subview) {
                return sv
            }
        }
        return nil
    }

    private func scroll(_ clipView: NSClipView, by delta: CGFloat) {
        var origin = clipView.bounds.origin
        origin.y += delta
        origin.y = max(0, origin.y)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            clipView.animator().setBoundsOrigin(origin)
        }
    }

    private func scrollToTop(_ clipView: NSClipView) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            clipView.animator().setBoundsOrigin(.zero)
        }
    }

    private func scrollToBottom(_ clipView: NSClipView, scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let maxY = max(0, documentView.frame.height - clipView.bounds.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            clipView.animator().setBoundsOrigin(NSPoint(x: 0, y: maxY))
        }
    }

    private func toggleHelp() {
        guard let window = NSApp.keyWindow else { return }
        HelpOverlay.toggle(in: window)
    }
}

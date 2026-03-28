import AppKit
import MarkdownParser
import MarkdownView
import SwiftUI

/// Mirrors the Quick Look extension rendering in a regular app window.
/// Used in debug builds to iterate on QL rendering without reinstalling.
@MainActor
final class QLPreviewWindow: NSObject {
    private let window: NSWindow
    private let scrollView: NSScrollView
    private let markdownTextView: MarkdownTextView
    private var infoOverlay: NSView?

    private let padding: CGFloat = 32.0

    private static var openWindows: [QLPreviewWindow] = []

    static func show(markdown: String, title: String, baseURL: URL?) {
        let preview = QLPreviewWindow(markdown: markdown, title: title, baseURL: baseURL)
        openWindows.append(preview)
        preview.window.makeKeyAndOrderFront(nil)
    }

    private init(markdown: String, title: String, baseURL: URL?) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))

        scrollView = NSScrollView(frame: container.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        markdownTextView = MarkdownTextView()
        scrollView.documentView = markdownTextView
        scrollView.contentView.postsBoundsChangedNotifications = true
        container.addSubview(scrollView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QL Preview: \(title)"
        window.contentView = container
        window.isReleasedWhenClosed = false
        window.center()

        super.init()

        window.delegate = self
        render(markdown: markdown, baseURL: baseURL)
    }

    private func render(markdown: String, baseURL: URL?) {
        let parsed = FrontmatterParser.parse(markdown)
        let body = parsed.body
        let fields = parsed.fields

        let isDark = window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = MarkdownGitHubTheme.theme(dark: isDark)

        let parser = MarkdownParser()
        let result = parser.parse(body)
        let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
        content.loadedImages = ImageLoader.loadImages(from: body, baseURL: baseURL)

        // Size window to a comfortable reading width
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1440
        let windowWidth = min(800.0, screenWidth * 0.6)
        let windowHeight = min(max(windowWidth * 1.5, 700), screenWidth * 0.85)
        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        window.center()

        markdownTextView.theme = theme
        markdownTextView.setMarkdownManually(content)
        markdownTextView.bindContentOffset(from: scrollView)

        let bgColor = MarkdownGitHubTheme.backgroundColor(dark: isDark)
        markdownTextView.wantsLayer = true
        markdownTextView.layer?.backgroundColor = bgColor.cgColor
        scrollView.backgroundColor = bgColor
        scrollView.drawsBackground = true

        relayout()
        updateInfoOverlay(fields: fields)
        updateDebugLozenge()
    }

    private func relayout() {
        guard let container = window.contentView else { return }
        let scrollWidth = scrollView.contentView.bounds.width
        guard scrollWidth > 0 else {
            // Defer until the window is laid out
            DispatchQueue.main.async { [weak self] in self?.relayout() }
            return
        }
        let contentWidth = scrollWidth - (padding * 2)
        markdownTextView.textView.preferredMaxLayoutWidth = contentWidth
        let contentSize = markdownTextView.boundingSize(for: contentWidth)
        markdownTextView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentSize.height)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: -padding)
        scrollView.documentView?.scroll(NSPoint(x: 0, y: -padding))
        repositionInfoOverlay()
        _ = container  // suppress unused warning
    }

    private func updateInfoOverlay(fields: [(key: String, value: String)]) {
        infoOverlay?.removeFromSuperview()
        infoOverlay = nil
        guard !fields.isEmpty, let container = window.contentView else { return }

        let hosting = NSHostingView(rootView: QLPreviewInfoButton(fields: fields))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear
        hosting.autoresizingMask = [.minXMargin, .minYMargin]
        hosting.isHidden = true
        container.addSubview(hosting)
        infoOverlay = hosting
        repositionInfoOverlay()
    }

    private func updateDebugLozenge() {
        guard markaIsDebugBuild, let container = window.contentView else { return }
        let lozengeView = Text("v\(markaVersion) #\(markaBuildNumber)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(10)
            .allowsHitTesting(false)
        let hosting = NSHostingView(rootView: lozengeView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear
        hosting.autoresizingMask = [.maxXMargin, .maxYMargin]
        container.addSubview(hosting)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
    }

    private func repositionInfoOverlay() {
        guard let overlay = infoOverlay, let container = window.contentView else { return }
        let bounds = container.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let size: CGFloat = 44
        let margin: CGFloat = 10
        overlay.frame = NSRect(
            x: bounds.width - size - margin,
            y: bounds.height - size - margin,
            width: size,
            height: size
        )
        overlay.isHidden = false
    }
}

extension QLPreviewWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Self.openWindows.removeAll { $0 === self }
    }
}

private struct QLPreviewInfoButton: View {
    let fields: [(key: String, value: String)]
    @State private var showingInfo = false

    var body: some View {
        Button {
            showingInfo.toggle()
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingInfo) {
            FrontmatterInfoView(fields: fields)
        }
    }
}

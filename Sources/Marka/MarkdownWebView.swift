import AppKit
import MarkdownParser
import MarkdownView
import SwiftUI

struct MarkdownNativeView: NSViewRepresentable {
    let document: MarkdownDocument

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = true

        let markdownTextView = MarkdownTextView()
        markdownTextView.linkHandler = { payload, _, _ in
            switch payload {
            case .url(let url):
                NSWorkspace.shared.open(url)
            case .string(let str):
                if let url = URL(string: str) {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        scrollView.documentView = markdownTextView
        scrollView.contentView.postsBoundsChangedNotifications = true
        markdownTextView.bindContentOffset(from: scrollView)

        context.coordinator.markdownTextView = markdownTextView
        context.coordinator.scrollView = scrollView

        // Register so AppDelegate can find this coordinator
        AppDelegate.coordinatorRegistry[ObjectIdentifier(markdownTextView)] = context.coordinator
        context.coordinator.observeFrameChanges()
        context.coordinator.observeAppearanceChanges()

        renderContent(markdownTextView: markdownTextView, scrollView: scrollView, coordinator: context.coordinator)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard document.markdown != context.coordinator.lastMarkdown,
              let markdownTextView = context.coordinator.markdownTextView else { return }

        renderContent(markdownTextView: markdownTextView, scrollView: scrollView, coordinator: context.coordinator)
    }

    private func renderContent(markdownTextView: MarkdownTextView, scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.lastMarkdown = document.markdown
        coordinator.baseURL = document.baseURL

        let isDark = scrollView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = MarkdownGitHubTheme.theme(dark: isDark)
        let scaledTheme = coordinator.applyZoom(to: theme)

        let parser = MarkdownParser()
        let result = parser.parse(document.markdown)
        let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: scaledTheme)
        content.loadedImages = ImageLoader.loadImages(from: document.markdown, baseURL: document.baseURL)

        let scrollWidth = scrollView.contentView.bounds.width
        var contentWidth = scrollWidth - (coordinator.padding * 2)
        if coordinator.narrowLayout {
            contentWidth = min(contentWidth, 980)
        }
        content.contentWidth = contentWidth

        markdownTextView.theme = scaledTheme
        markdownTextView.setMarkdownManually(content)

        let bgColor = MarkdownGitHubTheme.backgroundColor(dark: isDark)
        markdownTextView.wantsLayer = true
        markdownTextView.layer?.backgroundColor = bgColor.cgColor
        scrollView.backgroundColor = bgColor

        Self.relayout(markdownTextView: markdownTextView, scrollView: scrollView, coordinator: coordinator)
    }

    static func relayout(markdownTextView: MarkdownTextView, scrollView: NSScrollView, coordinator: Coordinator) {
        let padding = coordinator.padding
        let scrollWidth = scrollView.contentView.bounds.width
        guard scrollWidth > 0 else { return }

        var contentWidth = scrollWidth - (padding * 2)
        if coordinator.narrowLayout {
            contentWidth = min(contentWidth, 980)
        }

        markdownTextView.textView.preferredMaxLayoutWidth = contentWidth
        let contentSize = markdownTextView.boundingSize(for: contentWidth)
        markdownTextView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentSize.height)

        scrollView.automaticallyAdjustsContentInsets = false
        if coordinator.narrowLayout && scrollWidth - (padding * 2) > 980 {
            let sideInset = (scrollWidth - 980) / 2
            scrollView.contentInsets = NSEdgeInsets(top: padding, left: sideInset, bottom: padding, right: sideInset)
            scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: -sideInset)
        } else {
            scrollView.contentInsets = NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
            scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: -padding)
        }
    }

    final class Coordinator: NSObject {
        var markdownTextView: MarkdownTextView?
        var scrollView: NSScrollView?
        var lastMarkdown: String = ""
        var baseURL: URL?
        let padding: CGFloat = 32.0
        var narrowLayout: Bool = UserDefaults.standard.bool(forKey: "narrowLayout")
        var zoomLevel: CGFloat = 1.0
        var frameObserver: NSObjectProtocol?
        var appearanceObservation: NSKeyValueObservation?
        var lastIsDark: Bool?

        func applyZoom(to theme: MarkdownTheme) -> MarkdownTheme {
            guard zoomLevel != 1.0 else { return theme }
            var t = theme
            t.align(to: 16.0 * zoomLevel)
            return t
        }

        func observeFrameChanges() {
            guard let scrollView = scrollView, frameObserver == nil else { return }
            scrollView.contentView.postsFrameChangedNotifications = true
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                guard let self = self,
                      let mtv = self.markdownTextView,
                      let sv = self.scrollView else { return }
                MarkdownNativeView.relayout(markdownTextView: mtv, scrollView: sv, coordinator: self)
            }
        }

        func observeAppearanceChanges() {
            guard scrollView != nil, appearanceObservation == nil else { return }
            appearanceObservation = nil // mark as set up
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(systemAppearanceDidChange),
                name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil
            )
        }

        @objc private func systemAppearanceDidChange(_ notification: Notification) {
            self.perform(#selector(doCheckAppearanceChange), with: nil, afterDelay: 0.1)
        }

        @MainActor @objc private func doCheckAppearanceChange() {
            guard let scrollView = self.scrollView,
                  let markdownTextView = self.markdownTextView else { return }
            let isDark = scrollView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            guard isDark != self.lastIsDark else { return }
            self.lastIsDark = isDark
            self.rerenderForAppearance(markdownTextView: markdownTextView, scrollView: scrollView)
        }

        @MainActor
        private func rerenderForAppearance(markdownTextView: MarkdownTextView, scrollView: NSScrollView) {
            let isDark = scrollView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let theme = MarkdownGitHubTheme.theme(dark: isDark)
            let scaledTheme = applyZoom(to: theme)

            let parser = MarkdownParser()
            let result = parser.parse(lastMarkdown)
            let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: scaledTheme)
            content.loadedImages = ImageLoader.loadImages(from: lastMarkdown, baseURL: baseURL)
            let scrollWidth = scrollView.contentView.bounds.width
            var cw = scrollWidth - (padding * 2)
            if narrowLayout { cw = min(cw, 980) }
            content.contentWidth = cw
            markdownTextView.theme = scaledTheme
            markdownTextView.setMarkdownManually(content)

            let bgColor = MarkdownGitHubTheme.backgroundColor(dark: isDark)
            markdownTextView.wantsLayer = true
            markdownTextView.layer?.backgroundColor = bgColor.cgColor
            scrollView.backgroundColor = bgColor

            MarkdownNativeView.relayout(markdownTextView: markdownTextView, scrollView: scrollView, coordinator: self)
        }

        deinit {
            if let observer = frameObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

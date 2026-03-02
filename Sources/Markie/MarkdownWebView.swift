import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let document: MarkdownDocument

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        // Load initial content
        let html = HTMLTemplate.fullPage(markdown: document.markdown)
        webView.loadHTMLString(html, baseURL: document.baseURL)
        context.coordinator.lastMarkdown = document.markdown

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard document.markdown != context.coordinator.lastMarkdown else { return }
        context.coordinator.lastMarkdown = document.markdown

        if context.coordinator.pageLoaded {
            pushMarkdownUpdate(webView: webView, markdown: document.markdown)
        } else {
            // Page not yet loaded, reload entirely
            let html = HTMLTemplate.fullPage(markdown: document.markdown)
            webView.loadHTMLString(html, baseURL: document.baseURL)
        }
    }

    private func pushMarkdownUpdate(webView: WKWebView, markdown: String) {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        webView.evaluateJavaScript("updateMarkdown(`\(escaped)`)")
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var webView: WKWebView?
        var lastMarkdown: String = ""
        var pageLoaded = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

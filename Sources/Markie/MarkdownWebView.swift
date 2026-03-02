import SwiftUI
import WebKit
import Ink

struct MarkdownWebView: NSViewRepresentable {
    let document: MarkdownDocument

    private static let parser = MarkdownParser()

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

        let bodyHTML = Self.parser.html(from: document.markdown)
        let html = HTMLTemplate.fullPage(bodyHTML: bodyHTML)
        webView.loadHTMLString(html, baseURL: document.baseURL)
        context.coordinator.lastMarkdown = document.markdown

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard document.markdown != context.coordinator.lastMarkdown else { return }
        context.coordinator.lastMarkdown = document.markdown

        let bodyHTML = Self.parser.html(from: document.markdown)

        if context.coordinator.pageLoaded {
            pushHTMLUpdate(webView: webView, html: bodyHTML)
        } else {
            let fullHTML = HTMLTemplate.fullPage(bodyHTML: bodyHTML)
            webView.loadHTMLString(fullHTML, baseURL: document.baseURL)
        }
    }

    private func pushHTMLUpdate(webView: WKWebView, html: String) {
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        webView.evaluateJavaScript("updateContent(`\(escaped)`)")
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

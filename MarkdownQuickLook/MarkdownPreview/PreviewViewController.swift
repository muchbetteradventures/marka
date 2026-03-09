import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 800), configuration: config)
        webView.autoresizingMask = [.width, .height]
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let html: String
            let baseURL: URL?

            switch url.pathExtension.lowercased() {
            case "md", "markdown":
                let content = try String(contentsOf: url, encoding: .utf8)
                baseURL = url.deletingLastPathComponent()
                html = renderMarkdown(content, baseURL: baseURL)

            case "textbundle":
                let bundle = try readTextBundle(at: url)
                baseURL = bundle.assetsURL
                html = renderMarkdown(bundle.markdown, baseURL: baseURL)

            case "textpack":
                let bundle = try readTextPack(at: url)
                baseURL = bundle.assetsURL
                html = renderMarkdown(bundle.markdown, baseURL: baseURL)

            default:
                handler(PreviewError.unsupportedFormat)
                return
            }

            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: baseURL)
                handler(nil)
            }
        } catch {
            handler(error)
        }
    }

    // MARK: - Markdown Rendering

    private func renderMarkdown(_ content: String, baseURL: URL?) -> String {
        // Simple markdown to HTML conversion
        var html = content

        // Escape HTML first
        html = html
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Code blocks (fenced)
        html = html.replacingOccurrences(
            of: "```([a-z]*)\\n([\\s\\S]*?)```",
            with: "<pre><code class=\"language-$1\">$2</code></pre>",
            options: .regularExpression
        )

        // Inline code
        html = html.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Headers
        html = html.replacingOccurrences(of: "(?m)^###### (.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##### (.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)

        // Images - resolve relative paths
        if let base = baseURL {
            html = html.replacingOccurrences(
                of: "!\\[([^\\]]*)\\]\\((?!http)([^)]+)\\)",
                with: "![$1](\(base.absoluteString)/$2)",
                options: .regularExpression
            )
        }

        // Images to HTML
        html = html.replacingOccurrences(
            of: "!\\[([^\\]]*)\\]\\(([^)]+)\\)",
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )

        // Links
        html = html.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        // Horizontal rules
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\*\\*\\*+$", with: "<hr>", options: .regularExpression)

        // Unordered lists
        html = html.replacingOccurrences(of: "(?m)^[*-] (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Ordered lists
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^> (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)

        // Paragraphs - wrap loose lines
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var inParagraph = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if inParagraph {
                    result.append("</p>")
                    inParagraph = false
                }
                result.append("")
            } else if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<pre") ||
                      trimmed.hasPrefix("<li") || trimmed.hasPrefix("<blockquote") ||
                      trimmed.hasPrefix("<hr") || trimmed.hasPrefix("<img") {
                if inParagraph {
                    result.append("</p>")
                    inParagraph = false
                }
                result.append(line)
            } else {
                if !inParagraph {
                    result.append("<p>")
                    inParagraph = true
                }
                result.append(line)
            }
        }
        if inParagraph {
            result.append("</p>")
        }

        html = result.joined(separator: "\n")

        return wrapInHTML(body: html)
    }

    private func wrapInHTML(body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                \(Self.cssStyle)
            </style>
        </head>
        <body>
            <article class="markdown-body">
                \(body)
            </article>
        </body>
        </html>
        """
    }

    // MARK: - TextBundle Support

    private struct BundleContent {
        let markdown: String
        let assetsURL: URL?
    }

    private func readTextBundle(at url: URL) throws -> BundleContent {
        let textMD = url.appendingPathComponent("text.md")
        let textMarkdown = url.appendingPathComponent("text.markdown")

        let markdownURL: URL
        if FileManager.default.fileExists(atPath: textMD.path) {
            markdownURL = textMD
        } else if FileManager.default.fileExists(atPath: textMarkdown.path) {
            markdownURL = textMarkdown
        } else {
            throw PreviewError.missingMarkdownFile
        }

        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)

        let assetsURL = url.appendingPathComponent("assets")
        let hasAssets = FileManager.default.fileExists(atPath: assetsURL.path)

        return BundleContent(
            markdown: markdown,
            assetsURL: hasAssets ? assetsURL : url
        )
    }

    private func readTextPack(at url: URL) throws -> BundleContent {
        // Extract to temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ql-textpack-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Use unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", url.path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PreviewError.extractionFailed
        }

        // Find textbundle or use root
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )

        let bundleURL: URL
        if let textbundleDir = contents.first(where: { $0.pathExtension == "textbundle" }) {
            bundleURL = textbundleDir
        } else {
            bundleURL = tempDir
        }

        return try readTextBundle(at: bundleURL)
    }

    // MARK: - CSS

    private static let cssStyle = """
        :root {
            color-scheme: light dark;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            padding: 20px;
            max-width: 900px;
            margin: 0 auto;
            background: #ffffff;
            color: #24292e;
        }

        @media (prefers-color-scheme: dark) {
            body {
                background: #0d1117;
                color: #c9d1d9;
            }
            a { color: #58a6ff; }
            code { background: #161b22; }
            pre { background: #161b22; border-color: #30363d; }
            blockquote { border-left-color: #3b434b; color: #8b949e; }
        }

        .markdown-body { word-wrap: break-word; }

        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }

        h1 { font-size: 2em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }

        p { margin-top: 0; margin-bottom: 16px; }

        a { color: #0366d6; text-decoration: none; }
        a:hover { text-decoration: underline; }

        code {
            font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 85%;
            background: #f6f8fa;
            padding: 0.2em 0.4em;
            border-radius: 6px;
        }

        pre {
            font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 85%;
            background: #f6f8fa;
            padding: 16px;
            overflow: auto;
            border-radius: 6px;
            border: 1px solid #e1e4e8;
        }

        pre code { background: transparent; padding: 0; }

        blockquote {
            margin: 0;
            padding: 0 1em;
            color: #6a737d;
            border-left: 0.25em solid #dfe2e5;
        }

        ul, ol { padding-left: 2em; margin-top: 0; margin-bottom: 16px; }
        li { margin-top: 0.25em; }

        img { max-width: 100%; height: auto; border-radius: 6px; }

        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background: #e1e4e8;
            border: 0;
        }
        """
}

enum PreviewError: LocalizedError {
    case unsupportedFormat
    case missingMarkdownFile
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format"
        case .missingMarkdownFile:
            return "TextBundle does not contain text.md"
        case .extractionFailed:
            return "Failed to extract TextPack"
        }
    }
}

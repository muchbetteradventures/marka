import Foundation
import Markdown

/// Renders markdown content to HTML with styling
public struct MarkdownRenderer {

    public init() {}

    /// Render markdown string to complete HTML document
    public func render(markdown: String, baseURL: URL? = nil) -> String {
        let document = Document(parsing: markdown)
        var htmlVisitor = HTMLVisitor(baseURL: baseURL)
        let bodyHTML = htmlVisitor.visit(document)

        return wrapInHTML(body: bodyHTML)
    }

    /// Render markdown file to HTML
    public func renderFile(at url: URL) throws -> String {
        let content = try String(contentsOf: url, encoding: .utf8)
        let baseURL = url.deletingLastPathComponent()
        return render(markdown: content, baseURL: baseURL)
    }

    /// Render TextBundle to HTML
    public func renderTextBundle(at url: URL) throws -> String {
        let bundle = try TextBundleReader.read(at: url)
        return render(markdown: bundle.markdown, baseURL: bundle.assetsURL)
    }

    /// Render TextPack to HTML
    public func renderTextPack(at url: URL) throws -> String {
        let bundle = try TextPackReader.read(at: url)
        return render(markdown: bundle.markdown, baseURL: bundle.assetsURL)
    }

    private func wrapInHTML(body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
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

            code {
                background: #161b22;
            }

            pre {
                background: #161b22;
                border-color: #30363d;
            }

            blockquote {
                border-left-color: #3b434b;
                color: #8b949e;
            }

            table th, table td {
                border-color: #30363d;
            }

            hr {
                background: #21262d;
            }
        }

        .markdown-body {
            word-wrap: break-word;
        }

        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }

        h1 { font-size: 2em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #6a737d; }

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

        pre code {
            background: transparent;
            padding: 0;
            border-radius: 0;
        }

        blockquote {
            margin: 0;
            padding: 0 1em;
            color: #6a737d;
            border-left: 0.25em solid #dfe2e5;
        }

        ul, ol {
            padding-left: 2em;
            margin-top: 0;
            margin-bottom: 16px;
        }

        li { margin-top: 0.25em; }
        li + li { margin-top: 0.25em; }

        img {
            max-width: 100%;
            height: auto;
            border-radius: 6px;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }

        table th, table td {
            padding: 6px 13px;
            border: 1px solid #dfe2e5;
        }

        table th {
            font-weight: 600;
            background: #f6f8fa;
        }

        table tr:nth-child(2n) {
            background: #f6f8fa;
        }

        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background: #e1e4e8;
            border: 0;
        }

        .task-list-item {
            list-style-type: none;
        }

        .task-list-item input {
            margin: 0 0.2em 0.25em -1.4em;
            vertical-align: middle;
        }
        """
}

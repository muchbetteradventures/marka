import Foundation

/// Simple Swift-side markdown-to-HTML renderer for QuickLook previews.
/// Doesn't need to be perfect, just good enough for a quick preview.
enum QLMarkdownRenderer {

    static func render(_ markdown: String) -> String {
        var html = markdown

        // Escape HTML first
        html = html
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Fenced code blocks (must come before inline patterns)
        html = html.replacingOccurrences(
            of: "```([a-zA-Z]*)\\n([\\s\\S]*?)\\n```",
            with: "<pre><code class=\"language-$1\">$2</code></pre>",
            options: .regularExpression
        )

        // Inline code
        html = html.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Headers (process largest first to avoid partial matches)
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

        // Images
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

        // Task list items (before regular list items)
        html = html.replacingOccurrences(of: "(?m)^[*-] \\[x\\] (.+)$", with: "<li class=\"task-list-item\"><input type=\"checkbox\" checked disabled> $1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^[*-] \\[ \\] (.+)$", with: "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> $1</li>", options: .regularExpression)

        // Unordered list items
        html = html.replacingOccurrences(of: "(?m)^[*-] (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Ordered list items
        html = html.replacingOccurrences(of: "(?m)^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)

        // Blockquotes
        html = html.replacingOccurrences(of: "(?m)^&gt; (.+)$", with: "<blockquote><p>$1</p></blockquote>", options: .regularExpression)

        // Wrap loose lines in paragraphs
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var inParagraph = false

        let blockTags = ["<h", "<pre", "<li", "<blockquote", "<hr", "<img", "<table", "<ul", "<ol"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isBlock = blockTags.contains(where: { trimmed.hasPrefix($0) })
                || trimmed.hasPrefix("</")

            if trimmed.isEmpty {
                if inParagraph {
                    result.append("</p>")
                    inParagraph = false
                }
                result.append("")
            } else if isBlock {
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

        return result.joined(separator: "\n")
    }
}

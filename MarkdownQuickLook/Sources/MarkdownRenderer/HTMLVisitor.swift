import Foundation
import Markdown

/// Converts Markdown AST to HTML
struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    let baseURL: URL?

    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
    }

    mutating func defaultVisit(_ markup: any Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    // MARK: - Block Elements

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined()
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let content = heading.children.map { visit($0) }.joined()
        return "<h\(heading.level)>\(content)</h\(heading.level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let content = paragraph.children.map { visit($0) }.joined()
        return "<p>\(content)</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined()
        return "<blockquote>\n\(content)</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let escaped = escapeHTML(codeBlock.code)
        let langAttr = codeBlock.language.map { " class=\"language-\($0)\"" } ?? ""
        return "<pre><code\(langAttr)>\(escaped)</code></pre>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        let items = unorderedList.children.map { visit($0) }.joined()
        return "<ul>\n\(items)</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let items = orderedList.children.map { visit($0) }.joined()
        let start = orderedList.startIndex != 1 ? " start=\"\(orderedList.startIndex)\"" : ""
        return "<ol\(start)>\n\(items)</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let content = listItem.children.map { visit($0) }.joined()
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            return "<li class=\"task-list-item\"><input type=\"checkbox\" disabled\(checked)>\(content)</li>\n"
        }
        return "<li>\(content)</li>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML
    }

    mutating func visitTable(_ table: Table) -> String {
        let head = table.head.cells.map { cell -> String in
            var content = ""
            var visitor = self
            content = cell.children.map { visitor.visit($0) }.joined()
            return "<th>\(content)</th>"
        }.joined()

        let bodyRows = table.body.rows.map { row -> String in
            let cells = row.cells.map { cell -> String in
                var content = ""
                var visitor = self
                content = cell.children.map { visitor.visit($0) }.joined()
                return "<td>\(content)</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined("\n")

        return """
        <table>
        <thead><tr>\(head)</tr></thead>
        <tbody>
        \(bodyRows)
        </tbody>
        </table>

        """
    }

    // MARK: - Inline Elements

    mutating func visitText(_ text: Text) -> String {
        escapeHTML(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "<em>\(content)</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "<strong>\(content)</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()
        return "<del>\(content)</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        inlineHTML.rawHTML
    }

    mutating func visitLink(_ link: Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let href = escapeAttribute(link.destination ?? "")
        let title = link.title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""
        return "<a href=\"\(href)\"\(title)>\(content)</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        var src = image.source ?? ""

        // Resolve relative paths against baseURL
        if let baseURL = baseURL, !src.hasPrefix("http://") && !src.hasPrefix("https://") && !src.hasPrefix("data:") {
            let imageURL = baseURL.appendingPathComponent(src)
            src = imageURL.absoluteString
        }

        let alt = escapeAttribute(image.plainText)
        let title = image.title.map { " title=\"\(escapeAttribute($0))\"" } ?? ""
        return "<img src=\"\(escapeAttribute(src))\" alt=\"\(alt)\"\(title)>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeAttribute(_ string: String) -> String {
        escapeHTML(string)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

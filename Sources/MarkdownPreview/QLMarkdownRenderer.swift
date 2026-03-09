import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Markdown-to-HTML renderer for QuickLook previews using cmark-gfm.
/// Produces proper GFM HTML with tables, strikethrough, autolinks, and task lists.
enum QLMarkdownRenderer {

    /// GFM extension names to enable.
    private static let extensionNames = ["table", "strikethrough", "autolink", "tasklist"]

    static func render(_ markdown: String) -> String {
        // Register GFM extensions (safe to call multiple times).
        cmark_gfm_core_extensions_ensure_registered()

        let options: Int32 = CMARK_OPT_UNSAFE | CMARK_OPT_SMART | CMARK_OPT_FOOTNOTES

        // Create parser and attach extensions.
        guard let parser = cmark_parser_new(options) else {
            return escapeHTML(markdown)
        }
        defer { cmark_parser_free(parser) }

        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        // Feed the markdown text.
        let data = Array(markdown.utf8)
        cmark_parser_feed(parser, data.map { CChar(bitPattern: $0) }, data.count)

        // Finish parsing.
        guard let doc = cmark_parser_finish(parser) else {
            return escapeHTML(markdown)
        }
        defer { cmark_node_free(doc) }

        // Render to HTML with extensions list.
        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let cString = cmark_render_html(doc, options, extensions) else {
            return escapeHTML(markdown)
        }
        defer { free(cString) }

        return String(cString: cString)
    }

    /// Fallback HTML escaping if cmark fails.
    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

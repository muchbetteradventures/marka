import Foundation

/// Static HTML template for QuickLook previews.
/// Uses the same CSS as the main app but no JavaScript.
enum QLHTMLTemplate {
    static func page(renderedHTML: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(HTMLTemplate.styleBlock)
        </head>
        <body>
        <article class="markdown-body" id="content">
        \(renderedHTML)
        </article>
        </body>
        </html>
        """
    }
}

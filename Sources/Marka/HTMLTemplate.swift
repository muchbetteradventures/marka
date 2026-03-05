import Foundation

enum HTMLTemplate {
    static func fullPage(markdown: String) -> String {
        let escapedMarkdown = markdown.jsTemplateEscaped
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        \(styleBlock)
        </head>
        <body>
        <article class="markdown-body" id="content"></article>
        \(vendorScriptBlock)
        \(appScriptBlock)
        <script>
        updateMarkdown(`\(escapedMarkdown)`);
        window.markaSetNarrowLayout(\(UserDefaults.standard.bool(forKey: "narrowLayout") ? "true" : "false"));
        </script>
        </body>
        </html>
        """
    }
}

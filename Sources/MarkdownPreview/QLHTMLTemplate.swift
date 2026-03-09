import Cocoa

/// Static HTML template for QuickLook previews.
/// Uses simple element-level CSS that NSAttributedString(html:) can actually render.
/// NSAttributedString ignores class selectors, CSS variables, and most modern CSS.
/// Dark mode is detected on the Swift side and baked into the CSS colours.
enum QLHTMLTemplate {

    private static var isDarkMode: Bool {
        NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func page(renderedHTML: String) -> String {
        let dark = isDarkMode

        let textColor = dark ? "#e6edf3" : "#1f2328"
        let bgColor = dark ? "#0d1117" : "#ffffff"
        let mutedText = dark ? "#9198a1" : "#656d76"
        let borderColor = dark ? "#3d444d" : "#d1d9e0"
        let linkColor = dark ? "#4493f8" : "#0969da"
        let codeBg = dark ? "#262c36" : "#eff1f3"
        let preBg = dark ? "#161b22" : "#f6f8fa"
        let thBg = dark ? "#161b22" : "#f6f8fa"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body {
            font-family: -apple-system, Helvetica, Arial, sans-serif;
            font-size: 15px;
            line-height: 1.6;
            color: \(textColor);
            background-color: \(bgColor);
            padding: 16px;
        }
        h1 { font-size: 28px; font-weight: 600; margin-top: 24px; margin-bottom: 16px; padding-bottom: 6px; border-bottom: 1px solid \(borderColor); }
        h2 { font-size: 22px; font-weight: 600; margin-top: 24px; margin-bottom: 16px; padding-bottom: 6px; border-bottom: 1px solid \(borderColor); }
        h3 { font-size: 18px; font-weight: 600; margin-top: 24px; margin-bottom: 16px; }
        h4 { font-size: 15px; font-weight: 600; margin-top: 24px; margin-bottom: 16px; }
        h5 { font-size: 13px; font-weight: 600; margin-top: 24px; margin-bottom: 16px; }
        h6 { font-size: 13px; font-weight: 600; color: \(mutedText); margin-top: 24px; margin-bottom: 16px; }
        p { margin-top: 0; margin-bottom: 16px; }
        a { color: \(linkColor); text-decoration: underline; }
        strong { font-weight: 600; }
        em { font-style: italic; }
        code {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 13px;
            background-color: \(codeBg);
            padding: 2px 6px;
            border-radius: 4px;
        }
        pre {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 13px;
            background-color: \(preBg);
            padding: 16px;
            border-radius: 6px;
            overflow: auto;
            margin-bottom: 16px;
        }
        pre code {
            background-color: transparent;
            padding: 0;
        }
        blockquote {
            color: \(mutedText);
            border-left: 4px solid \(borderColor);
            padding-left: 16px;
            margin-left: 0;
            margin-bottom: 16px;
        }
        ul, ol { padding-left: 2em; margin-bottom: 16px; }
        li { margin-bottom: 4px; }
        hr { border: none; border-top: 1px solid \(borderColor); margin: 24px 0; }
        table { border-collapse: collapse; margin-bottom: 16px; }
        th, td { border: 1px solid \(borderColor); padding: 6px 12px; }
        th { font-weight: 600; background-color: \(thBg); }
        del { text-decoration: line-through; }
        img { max-width: 100%; }
        </style>
        </head>
        <body>
        \(renderedHTML)
        </body>
        </html>
        """
    }
}

import MarkdownView

#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

enum MarkdownGitHubTheme {
    static func theme(dark: Bool) -> MarkdownTheme {
        var theme = MarkdownTheme()

        let bodySize: CGFloat = 16.0
        theme.align(to: bodySize)

        if dark {
            theme.colors.body = PlatformColor(red: 0.941, green: 0.965, blue: 0.988, alpha: 1.0)
            theme.colors.highlight = PlatformColor(red: 0.267, green: 0.576, blue: 0.973, alpha: 1.0)
            theme.colors.emphasis = PlatformColor(red: 0.267, green: 0.576, blue: 0.973, alpha: 1.0)
            theme.colors.code = PlatformColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
            theme.colors.codeBackground = PlatformColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)
            theme.colors.selectionBackground = PlatformColor(red: 0.267, green: 0.576, blue: 0.973, alpha: 0.2)
            theme.table.borderColor = PlatformColor(red: 0.239, green: 0.263, blue: 0.302, alpha: 1.0)
            theme.table.headerBackgroundColor = PlatformColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)
            theme.table.stripeCellBackgroundColor = PlatformColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 0.5)
        } else {
            theme.colors.body = PlatformColor(red: 0.122, green: 0.137, blue: 0.157, alpha: 1.0)
            theme.colors.highlight = PlatformColor(red: 0.035, green: 0.412, blue: 0.855, alpha: 1.0)
            theme.colors.emphasis = PlatformColor(red: 0.035, green: 0.412, blue: 0.855, alpha: 1.0)
            theme.colors.code = PlatformColor(red: 0.122, green: 0.137, blue: 0.157, alpha: 1.0)
            theme.colors.codeBackground = PlatformColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 1.0)
            theme.colors.selectionBackground = PlatformColor(red: 0.035, green: 0.412, blue: 0.855, alpha: 0.2)
            theme.table.borderColor = PlatformColor(red: 0.82, green: 0.851, blue: 0.878, alpha: 1.0)
            theme.table.headerBackgroundColor = PlatformColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 1.0)
            theme.table.stripeCellBackgroundColor = PlatformColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 0.5)
        }

        theme.spacings.general = 10
        theme.spacings.list = 4

        return theme
    }

    static func backgroundColor(dark: Bool) -> PlatformColor {
        dark
            ? PlatformColor(red: 0.051, green: 0.067, blue: 0.09, alpha: 1.0)
            : PlatformColor.white
    }
}

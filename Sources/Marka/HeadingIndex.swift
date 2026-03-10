import AppKit
import MarkdownView

/// Indexes heading positions in a MarkdownTextView for keyboard navigation.
struct HeadingIndex {
    struct Entry {
        let level: Int // 1-6
        let text: String
        let yPosition: CGFloat
    }

    let entries: [Entry]

    /// Build a heading index by parsing the markdown source for heading lines,
    /// then finding their positions in the attributed string.
    @MainActor
    static func build(from markdownTextView: MarkdownTextView, markdown: String) -> HeadingIndex {
        let attrStr = markdownTextView.textView.attributedText
        let textLayout = markdownTextView.textView.textLayout
        let plainText = attrStr.string as NSString

        var entries: [Entry] = []

        // Parse markdown for ATX headings (# style)
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }

            // Count heading level
            var level = 0
            for ch in trimmed {
                if ch == "#" { level += 1 } else { break }
            }
            guard level >= 1, level <= 6 else { continue }

            // Extract heading text (strip # and whitespace)
            let headingText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            guard !headingText.isEmpty else { continue }

            // Find this text in the attributed string
            let searchRange = NSRange(location: 0, length: plainText.length)
            let foundRange = plainText.range(of: headingText, options: [], range: searchRange)
            guard foundRange.location != NSNotFound else { continue }

            // Get the y-position
            let rects = textLayout.rects(for: foundRange)
            guard let rect = rects.first else { continue }

            entries.append(Entry(level: level, text: headingText, yPosition: rect.origin.y))
        }

        return HeadingIndex(entries: entries)
    }

    /// Find the next heading after the given scroll y-position.
    func nextHeading(after scrollY: CGFloat, majorOnly: Bool = false) -> Entry? {
        let filtered = majorOnly ? entries.filter({ $0.level <= 2 }) : entries
        return filtered.first(where: { $0.yPosition > scrollY + 1 })
    }

    /// Find the previous heading before the given scroll y-position.
    func previousHeading(before scrollY: CGFloat, majorOnly: Bool = false) -> Entry? {
        let filtered = majorOnly ? entries.filter({ $0.level <= 2 }) : entries
        return filtered.last(where: { $0.yPosition < scrollY - 1 })
    }
}

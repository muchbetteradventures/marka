// Adapted from Markdownosaur by Christian Selig (https://github.com/christianselig/Markdownosaur)
// Original: MIT License, Copyright (c) 2021 Christian Selig
// Ported from UIKit to AppKit for macOS QuickLook extension use.

import Cocoa
import Markdown

struct QLMarkdownRenderer: MarkupVisitor {
    let baseFontSize: CGFloat = 16.0

    private var isDarkMode: Bool {
        NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private var textColor: NSColor {
        isDarkMode ? NSColor(white: 0.9, alpha: 1.0) : NSColor(white: 0.12, alpha: 1.0)
    }

    private var secondaryTextColor: NSColor {
        NSColor.secondaryLabelColor
    }

    private var linkColor: NSColor {
        NSColor.linkColor
    }

    private var codeColor: NSColor {
        isDarkMode ? NSColor(white: 0.75, alpha: 1.0) : NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
    }

    private var codeBackgroundColor: NSColor {
        // CSS: --bgColor-muted: #161b22 dark / #f6f8fa light
        isDarkMode ? NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0) : NSColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 1.0)
    }

    private var inlineCodeBackgroundColor: NSColor {
        isDarkMode ? NSColor(white: 0.2, alpha: 1.0) : NSColor(white: 0.91, alpha: 1.0)
    }

    private var blockquoteBarColor: NSColor {
        isDarkMode ? NSColor(white: 0.35, alpha: 1.0) : NSColor(white: 0.78, alpha: 1.0)
    }

    private var borderColor: NSColor {
        isDarkMode ? NSColor(white: 0.25, alpha: 1.0) : NSColor(white: 0.82, alpha: 1.0)
    }

    /// Background colour matching the WKWebView dark theme (#0d1117)
    var backgroundColor: NSColor {
        isDarkMode ? NSColor(red: 0.051, green: 0.067, blue: 0.09, alpha: 1.0) : NSColor.white
    }

    init() {}

    mutating func attributedString(from markdown: String) -> NSAttributedString {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        return visit(document)
    }

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    mutating func visitText(_ text: Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText, attributes: [
            .font: NSFont.systemFont(ofSize: baseFontSize, weight: .regular),
            .foregroundColor: textColor
        ])
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in emphasis.children {
            result.append(visit(child))
        }
        result.applyEmphasis()
        return result
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strong.children {
            result.append(visit(child))
        }
        result.applyStrong()
        return result
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in paragraph.children {
            result.append(visit(child))
        }

        if !paragraph.isContainedInList {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3.0
            paragraphStyle.paragraphSpacing = 6.0
            result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        }

        if paragraph.hasSuccessor {
            result.append(paragraph.isContainedInList ? .singleNewline(withFontSize: baseFontSize) : .doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in heading.children {
            result.append(visit(child))
        }
        result.applyHeading(withLevel: heading.level)

        // Add paragraph style with spacing above headings
        let headingParagraphStyle = NSMutableParagraphStyle()
        headingParagraphStyle.paragraphSpacingBefore = heading.level <= 2 ? 12.0 : 8.0
        headingParagraphStyle.paragraphSpacing = 4.0
        result.addAttribute(.paragraphStyle, value: headingParagraphStyle, range: NSRange(location: 0, length: result.length))

        if heading.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in link.children {
            result.append(visit(child))
        }
        let url = link.destination != nil ? URL(string: link.destination!) : nil
        result.applyLink(withURL: url, color: linkColor)
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        return NSAttributedString(string: inlineCode.code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular),
            .foregroundColor: codeColor,
            .backgroundColor: inlineCodeBackgroundColor
        ])
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 4.0
        paragraphStyle.paragraphSpacing = 4.0
        paragraphStyle.headIndent = 12.0
        paragraphStyle.firstLineHeadIndent = 12.0
        paragraphStyle.tailIndent = -12.0

        let result = NSMutableAttributedString(string: codeBlock.code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular),
            .foregroundColor: codeColor,
            .backgroundColor: codeBackgroundColor,
            .paragraphStyle: paragraphStyle
        ])
        if codeBlock.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strikethrough.children {
            result.append(visit(child))
        }
        result.applyStrikethrough()
        return result
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)

        for listItem in unorderedList.listItems {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]
            let listItemParagraphStyle = NSMutableParagraphStyle()

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(unorderedList.listDepth))
            let spacingFromIndex: CGFloat = 8.0
            let bulletWidth = ceil(NSAttributedString(string: "•", attributes: [.font: font]).size().width)
            let firstTabLocation = leftMarginOffset + bulletWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex

            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]
            listItemParagraphStyle.headIndent = secondTabLocation
            listItemParagraphStyle.lineSpacing = 3.0
            listItemParagraphStyle.paragraphSpacing = 4.0

            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = font
            listItemAttributes[.foregroundColor] = textColor

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString
            listItemAttributedString.insert(NSAttributedString(string: "\t•\t", attributes: listItemAttributes), at: 0)
            result.append(listItemAttributedString)
        }

        if unorderedList.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in listItem.children {
            result.append(visit(child))
        }
        if listItem.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, listItem) in orderedList.listItems.enumerated() {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]
            let font = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
            let numeralFont = NSFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)
            let listItemParagraphStyle = NSMutableParagraphStyle()

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(orderedList.listDepth))
            let highestNumberInList = orderedList.childCount
            let numeralColumnWidth = ceil(NSAttributedString(string: "\(highestNumberInList).", attributes: [.font: numeralFont]).size().width)
            let spacingFromIndex: CGFloat = 8.0
            let firstTabLocation = leftMarginOffset + numeralColumnWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex

            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]
            listItemParagraphStyle.headIndent = secondTabLocation
            listItemParagraphStyle.lineSpacing = 3.0
            listItemParagraphStyle.paragraphSpacing = 4.0

            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = font
            listItemAttributes[.foregroundColor] = textColor

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString

            var numberAttributes = listItemAttributes
            numberAttributes[.font] = numeralFont
            let numberAttributedString = NSAttributedString(string: "\t\(index + 1).\t", attributes: numberAttributes)
            listItemAttributedString.insert(numberAttributedString, at: 0)

            result.append(listItemAttributedString)
        }

        if orderedList.hasSuccessor {
            result.append(orderedList.isContainedInList ? .singleNewline(withFontSize: baseFontSize) : .doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in blockQuote.children {
            let quoteParagraphStyle = NSMutableParagraphStyle()

            // Match CSS: padding 0 1em, no extra left margin. Tab stop for bar + content.
            let barWidth: CGFloat = 4.0  // .25em solid border
            let padding: CGFloat = 12.0  // ~1em padding after bar
            let nestOffset: CGFloat = CGFloat(blockQuote.quoteDepth) * (barWidth + padding)
            let contentIndent = barWidth + padding + nestOffset

            quoteParagraphStyle.headIndent = contentIndent
            quoteParagraphStyle.firstLineHeadIndent = nestOffset
            quoteParagraphStyle.paragraphSpacingBefore = 2.0
            quoteParagraphStyle.paragraphSpacing = 2.0
            quoteParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .left, location: contentIndent)
            ]

            let quoteAttributedString = visit(child).mutableCopy() as! NSMutableAttributedString

            // Prepend bar character with tab to align content
            let barAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .foregroundColor: blockquoteBarColor
            ]
            quoteAttributedString.insert(NSAttributedString(string: "▎\t", attributes: barAttributes), at: 0)

            let fullRange = NSRange(location: 0, length: quoteAttributedString.length)
            quoteAttributedString.addAttribute(.foregroundColor, value: secondaryTextColor, range: fullRange)
            quoteAttributedString.addAttribute(.paragraphStyle, value: quoteParagraphStyle, range: fullRange)

            result.append(quoteAttributedString)
        }

        if blockQuote.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 24.0)
        ])
        if thematicBreak.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitTable(_ table: Table) -> NSAttributedString {
        // Tables are hard to render natively in NSAttributedString.
        // Fall back to a simple text representation.
        let result = NSMutableAttributedString()
        for child in table.children {
            result.append(visit(child))
        }
        if table.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in tableHead.children {
            result.append(visit(child))
            result.append(NSAttributedString(string: "\n"))
        }
        result.applyStrong()
        return result
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in tableBody.children {
            result.append(visit(child))
            result.append(NSAttributedString(string: "\n"))
        }
        return result
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, cell) in tableRow.children.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  |  ", attributes: [
                    .font: NSFont.systemFont(ofSize: baseFontSize),
                    .foregroundColor: secondaryTextColor
                ]))
            }
            result.append(visit(cell))
        }
        return result
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in tableCell.children {
            result.append(visit(child))
        }
        return result
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
        return NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: baseFontSize)])
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        return .singleNewline(withFontSize: baseFontSize)
    }

    mutating func visitImage(_ image: Image) -> NSAttributedString {
        // Images can't be rendered in the QL sandbox easily; show alt text as a placeholder.
        let altText = image.plainText.isEmpty ? "[image]" : "[\(image.plainText)]"
        return NSAttributedString(string: altText, attributes: [
            .font: NSFont.systemFont(ofSize: baseFontSize, weight: .regular),
            .foregroundColor: secondaryTextColor
        ])
    }
}

// MARK: - NSMutableAttributedString Helpers

extension NSMutableAttributedString {
    fileprivate func applyEmphasis() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let newFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            addAttribute(.font, value: newFont, range: range)
        }
    }

    fileprivate func applyStrong() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let newFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            addAttribute(.font, value: newFont, range: range)
        }
    }

    fileprivate func applyLink(withURL url: URL?, color: NSColor) {
        addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: length))
        if let url = url {
            addAttribute(.link, value: url, range: NSRange(location: 0, length: length))
        }
    }

    fileprivate func applyHeading(withLevel headingLevel: Int) {
        // Match CSS: h1=2em, h2=1.5em, h3=1.25em, h4=1em, h5=.875em, h6=.85em (base 16px)
        let sizes: [CGFloat] = [32.0, 24.0, 20.0, 16.0, 14.0, 13.6]
        let newSize = sizes[min(headingLevel - 1, sizes.count - 1)]

        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            let sizedFont = NSFontManager.shared.convert(boldFont, toSize: newSize)
            addAttribute(.font, value: sizedFont, range: range)
        }
    }

    fileprivate func applyStrikethrough() {
        addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: length))
    }
}

// MARK: - Markup Helpers

extension ListItemContainer {
    var listDepth: Int {
        var index = 0
        var currentElement = parent
        while currentElement != nil {
            if currentElement is ListItemContainer { index += 1 }
            currentElement = currentElement?.parent
        }
        return index
    }
}

extension BlockQuote {
    var quoteDepth: Int {
        var index = 0
        var currentElement = parent
        while currentElement != nil {
            if currentElement is BlockQuote { index += 1 }
            currentElement = currentElement?.parent
        }
        return index
    }
}

extension Markup {
    var hasSuccessor: Bool {
        guard let childCount = parent?.childCount else { return false }
        return indexInParent < childCount - 1
    }

    var isContainedInList: Bool {
        var currentElement = parent
        while currentElement != nil {
            if currentElement is ListItemContainer { return true }
            currentElement = currentElement?.parent
        }
        return false
    }
}

extension NSAttributedString {
    static func singleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        return NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .regular)])
    }

    static func doubleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        return NSAttributedString(string: "\n\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .regular)])
    }
}

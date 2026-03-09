// Adapted from Markdownosaur by Christian Selig (https://github.com/christianselig/Markdownosaur)
// Original: MIT License, Copyright (c) 2021 Christian Selig
// Ported from UIKit to AppKit for macOS QuickLook extension use.

import Cocoa
import Markdown

struct QLMarkdownRenderer: MarkupVisitor {
    let baseFontSize: CGFloat = 15.0

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
        NSColor.secondaryLabelColor
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
            .foregroundColor: codeColor
        ])
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let result = NSMutableAttributedString(string: codeBlock.code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 1.0, weight: .regular),
            .foregroundColor: codeColor
        ])
        if codeBlock.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
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
            var quoteAttributes: [NSAttributedString.Key: Any] = [:]
            let quoteParagraphStyle = NSMutableParagraphStyle()

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(blockQuote.quoteDepth))

            quoteParagraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: leftMarginOffset)]
            quoteParagraphStyle.headIndent = leftMarginOffset

            quoteAttributes[.paragraphStyle] = quoteParagraphStyle
            quoteAttributes[.font] = NSFont.systemFont(ofSize: baseFontSize, weight: .regular)

            let quoteAttributedString = visit(child).mutableCopy() as! NSMutableAttributedString
            quoteAttributedString.insert(NSAttributedString(string: "\t", attributes: quoteAttributes), at: 0)
            quoteAttributedString.addAttribute(.foregroundColor, value: secondaryTextColor, range: NSRange(location: 0, length: quoteAttributedString.length))

            result.append(quoteAttributedString)
        }

        if blockQuote.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "\n\u{00A0}\n", attributes: [
            .font: NSFont.systemFont(ofSize: 4.0),
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: NSColor.separatorColor
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
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let newSize = 28.0 - CGFloat(headingLevel * 2)
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

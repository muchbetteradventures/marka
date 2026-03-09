import Cocoa
import Compression
import MarkdownParser
import MarkdownView
import Quartz

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {

    private var markdownTextView: MarkdownTextView!
    private var scrollView: NSScrollView!

    private let padding: CGFloat = 32.0

    override func loadView() {
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        markdownTextView = MarkdownTextView()

        scrollView.documentView = markdownTextView
        scrollView.contentView.postsBoundsChangedNotifications = true
        self.view = scrollView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        relayoutMarkdown()
    }

    private func relayoutMarkdown() {
        let scrollWidth = scrollView.contentView.bounds.width
        guard scrollWidth > 0 else { return }
        let contentWidth = scrollWidth - (padding * 2)
        markdownTextView.textView.preferredMaxLayoutWidth = contentWidth
        let contentSize = markdownTextView.boundingSize(for: contentWidth)
        markdownTextView.frame = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: contentSize.height
        )
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: -padding)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown: String

            switch url.pathExtension.lowercased() {
            case "md", "markdown", "mdown", "mkd":
                markdown = try String(contentsOf: url, encoding: .utf8)

            case "textbundle":
                let content = try TextBundleHandler.load(path: url.path)
                markdown = content.markdownContent

            case "textpack":
                let content = try QLTextPackReader.load(url: url)
                markdown = content.markdown

            default:
                handler(QLPreviewError.unsupportedFormat)
                return
            }

            let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let theme = Self.githubTheme(dark: isDark)

            let parser = MarkdownParser()
            let result = parser.parse(markdown)
            let content = MarkdownTextView.PreprocessedContent(parserResult: result, theme: theme)
            markdownTextView.theme = theme
            markdownTextView.setMarkdownManually(content)
            markdownTextView.bindContentOffset(from: scrollView)
            relayoutMarkdown()

            // Set background colour to match GitHub
            let bgColor = isDark
                ? NSColor(red: 0.051, green: 0.067, blue: 0.09, alpha: 1.0)  // #0d1117
                : NSColor.white
            markdownTextView.wantsLayer = true
            markdownTextView.layer?.backgroundColor = bgColor.cgColor
            scrollView.backgroundColor = bgColor
            scrollView.drawsBackground = true

            handler(nil)
        } catch {
            handler(error)
        }
    }

    /// Build a MarkdownTheme that matches the GitHub CSS from the WKWebView app.
    private static func githubTheme(dark: Bool) -> MarkdownTheme {
        var theme = MarkdownTheme()

        // Base font: 16px, line-height 1.5
        let bodySize: CGFloat = 16.0
        theme.align(to: bodySize)

        // Colours from HTMLStyles.swift CSS variables
        if dark {
            // --fgColor-default: #f0f6fc / #e6edf3
            theme.colors.body = NSColor(red: 0.941, green: 0.965, blue: 0.988, alpha: 1.0)
            // --fgColor-accent: #4493f8
            theme.colors.highlight = NSColor(red: 0.267, green: 0.576, blue: 0.973, alpha: 1.0)
            theme.colors.emphasis = NSColor(red: 0.267, green: 0.576, blue: 0.973, alpha: 1.0)
            // Code text: --fgColor-default on --bgColor-muted
            theme.colors.code = NSColor(red: 0.902, green: 0.929, blue: 0.953, alpha: 1.0)
            // --bgColor-muted: #161b22
            theme.colors.codeBackground = NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)
            // Selection
            theme.colors.selectionBackground = NSColor(red: 0.267, green: 0.576, blue: 0.973, alpha: 0.2)
            // Table
            theme.table.borderColor = NSColor(red: 0.239, green: 0.263, blue: 0.302, alpha: 1.0) // #3d444d
            theme.table.headerBackgroundColor = NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 1.0)
            theme.table.stripeCellBackgroundColor = NSColor(red: 0.086, green: 0.106, blue: 0.133, alpha: 0.5)
        } else {
            // --fgColor-default: #1f2328
            theme.colors.body = NSColor(red: 0.122, green: 0.137, blue: 0.157, alpha: 1.0)
            // --fgColor-accent: #0969da
            theme.colors.highlight = NSColor(red: 0.035, green: 0.412, blue: 0.855, alpha: 1.0)
            theme.colors.emphasis = NSColor(red: 0.035, green: 0.412, blue: 0.855, alpha: 1.0)
            // Code text
            theme.colors.code = NSColor(red: 0.122, green: 0.137, blue: 0.157, alpha: 1.0)
            // --bgColor-muted: #f6f8fa
            theme.colors.codeBackground = NSColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 1.0)
            // Selection
            theme.colors.selectionBackground = NSColor(red: 0.035, green: 0.412, blue: 0.855, alpha: 0.2)
            // Table
            theme.table.borderColor = NSColor(red: 0.82, green: 0.851, blue: 0.878, alpha: 1.0) // #d1d9e0
            theme.table.headerBackgroundColor = NSColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 1.0)
            theme.table.stripeCellBackgroundColor = NSColor(red: 0.965, green: 0.973, blue: 0.98, alpha: 0.5)
        }

        // Spacings
        theme.spacings.general = 10
        theme.spacings.list = 4

        return theme
    }
}

/// Minimal ZIP-based TextPack reader for sandboxed environments.
/// Cannot use Process/NSTask, so reads the ZIP directly via Foundation.
enum QLTextPackReader {
    struct Content {
        let markdown: String
        let baseURL: URL?
    }

    static func load(url: URL) throws -> Content {
        guard let archive = try? Data(contentsOf: url) else {
            throw QLPreviewError.extractionFailed
        }

        let markdown = try extractMarkdownFromZip(data: archive)
        return Content(markdown: markdown, baseURL: nil)
    }

    /// Minimal ZIP parser that finds and extracts text.md from a textpack.
    private static func extractMarkdownFromZip(data: Data) throws -> String {
        let signature: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
        var offset = 0

        while offset + 30 <= data.count {
            let headerBytes = [UInt8](data[offset..<offset+4])
            guard headerBytes == signature else { break }

            let compressionMethod = UInt16(data[offset+8]) | (UInt16(data[offset+9]) << 8)
            let compressedSize = Int(UInt32(data[offset+18]) | (UInt32(data[offset+19]) << 8) | (UInt32(data[offset+20]) << 16) | (UInt32(data[offset+21]) << 24))
            let uncompressedSize = Int(UInt32(data[offset+22]) | (UInt32(data[offset+23]) << 8) | (UInt32(data[offset+24]) << 16) | (UInt32(data[offset+25]) << 24))
            let fileNameLength = Int(UInt16(data[offset+26]) | (UInt16(data[offset+27]) << 8))
            let extraFieldLength = Int(UInt16(data[offset+28]) | (UInt16(data[offset+29]) << 8))

            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count else { break }

            let fileName = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8) ?? ""
            let dataStart = fileNameEnd + extraFieldLength

            let baseName = (fileName as NSString).lastPathComponent
            if baseName == "text.md" || baseName == "text.markdown" {
                guard dataStart + compressedSize <= data.count else {
                    throw QLPreviewError.extractionFailed
                }

                let fileData = data[dataStart..<dataStart+compressedSize]

                if compressionMethod == 0 {
                    guard let text = String(data: fileData, encoding: .utf8) else {
                        throw QLPreviewError.extractionFailed
                    }
                    return text
                } else if compressionMethod == 8 {
                    guard let decompressed = decompress(data: Data(fileData), uncompressedSize: uncompressedSize),
                          let text = String(data: decompressed, encoding: .utf8) else {
                        throw QLPreviewError.extractionFailed
                    }
                    return text
                } else {
                    throw QLPreviewError.extractionFailed
                }
            }

            offset = dataStart + compressedSize
        }

        throw QLPreviewError.missingMarkdownFile
    }

    private static func decompress(data: Data, uncompressedSize: Int) -> Data? {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { buffer.deallocate() }

        let decodedSize = data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = rawBuffer.baseAddress else { return 0 }
            return compression_decode_buffer(
                buffer, uncompressedSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decodedSize > 0 else { return nil }
        return Data(bytes: buffer, count: decodedSize)
    }
}

enum QLPreviewError: LocalizedError {
    case unsupportedFormat
    case extractionFailed
    case missingMarkdownFile
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format"
        case .extractionFailed:
            return "Failed to extract TextPack"
        case .missingMarkdownFile:
            return "TextBundle does not contain text.md"
        case .renderFailed:
            return "Failed to render markdown"
        }
    }
}

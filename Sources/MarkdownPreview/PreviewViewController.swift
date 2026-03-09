import Cocoa
import Compression
import Quartz

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {

    private var textView: NSTextView!
    private var scrollView: NSScrollView!

    override func loadView() {
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        self.view = scrollView
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

            let renderedHTML = QLMarkdownRenderer.render(markdown)
            let styledHTML = QLHTMLTemplate.page(renderedHTML: renderedHTML)

            guard let data = styledHTML.data(using: .utf8),
                  let attributedString = NSAttributedString(
                    html: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                  ) else {
                handler(QLPreviewError.renderFailed)
                return
            }

            textView.textStorage?.setAttributedString(attributedString)
            handler(nil)
        } catch {
            handler(error)
        }
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

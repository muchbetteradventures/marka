import Foundation

/// Content extracted from a TextBundle
public struct TextBundleContent {
    public let markdown: String
    public let assetsURL: URL?
    public let info: TextBundleInfo?
}

/// TextBundle info.json structure
public struct TextBundleInfo: Codable {
    public let version: Int
    public let type: String?
    public let transient: Bool?
    public let creatorURL: String?
    public let creatorIdentifier: String?
    public let sourceURL: String?
}

/// Reads TextBundle packages (.textbundle directories)
public enum TextBundleReader {

    public static func read(at url: URL) throws -> TextBundleContent {
        let fm = FileManager.default

        // Find markdown file
        let textMD = url.appendingPathComponent("text.md")
        let textMarkdown = url.appendingPathComponent("text.markdown")

        let markdownURL: URL
        if fm.fileExists(atPath: textMD.path) {
            markdownURL = textMD
        } else if fm.fileExists(atPath: textMarkdown.path) {
            markdownURL = textMarkdown
        } else {
            throw TextBundleError.missingMarkdownFile
        }

        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)

        // Check for assets folder
        let assetsURL = url.appendingPathComponent("assets")
        let hasAssets = fm.fileExists(atPath: assetsURL.path)

        // Read info.json if present
        let infoURL = url.appendingPathComponent("info.json")
        var info: TextBundleInfo?
        if fm.fileExists(atPath: infoURL.path) {
            let data = try Data(contentsOf: infoURL)
            info = try? JSONDecoder().decode(TextBundleInfo.self, from: data)
        }

        return TextBundleContent(
            markdown: markdown,
            assetsURL: hasAssets ? assetsURL : url,
            info: info
        )
    }
}

public enum TextBundleError: LocalizedError {
    case missingMarkdownFile
    case invalidArchive
    case extractionFailed

    public var errorDescription: String? {
        switch self {
        case .missingMarkdownFile:
            return "TextBundle does not contain text.md or text.markdown"
        case .invalidArchive:
            return "Invalid TextPack archive"
        case .extractionFailed:
            return "Failed to extract TextPack contents"
        }
    }
}

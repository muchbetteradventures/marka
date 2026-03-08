import Foundation
import Compression

/// Represents a parsed TextBundle or TextPack
struct TextBundleContent {
    let markdownContent: String
    let markdownFilePath: String  // Path to text.md (for file watching)
    let assetsPath: URL?          // Path to assets folder (for baseURL)
    let bundlePath: String        // Original bundle path
    let title: String
    let info: TextBundleInfo?
    let isTextPack: Bool
    let extractedPath: String?    // For textpack: path to extracted temp directory
}

/// TextBundle info.json structure
struct TextBundleInfo: Codable {
    let version: Int?
    let type: String?
    let transient: Bool?
    let creatorIdentifier: String?
    let sourceURL: String?
}

enum TextBundleError: Error, LocalizedError {
    case notABundle
    case missingTextFile
    case cannotReadContent
    case invalidTextPack
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .notABundle:
            return "Not a valid TextBundle or TextPack"
        case .missingTextFile:
            return "Bundle does not contain text.md or text.txt"
        case .cannotReadContent:
            return "Cannot read bundle content"
        case .invalidTextPack:
            return "Invalid TextPack archive"
        case .extractionFailed:
            return "Failed to extract TextPack"
        }
    }
}

enum TextBundleHandler {

    /// Check if a path is a TextBundle or TextPack
    static func isTextBundle(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        return ext == "textbundle" || ext == "textpack"
    }

    /// Check if path is a TextPack (compressed)
    static func isTextPack(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return url.pathExtension.lowercased() == "textpack"
    }

    /// Load a TextBundle or TextPack from path
    static func load(path: String) throws -> TextBundleContent {
        if isTextPack(path: path) {
            return try loadTextPack(path: path)
        } else {
            return try loadTextBundle(path: path)
        }
    }

    /// Load an uncompressed .textbundle directory
    private static func loadTextBundle(path: String) throws -> TextBundleContent {
        let bundleURL = URL(fileURLWithPath: path)

        // Find the text file (text.md or text.txt)
        let textMdURL = bundleURL.appendingPathComponent("text.md")
        let textTxtURL = bundleURL.appendingPathComponent("text.txt")

        let textFileURL: URL
        if FileManager.default.fileExists(atPath: textMdURL.path) {
            textFileURL = textMdURL
        } else if FileManager.default.fileExists(atPath: textTxtURL.path) {
            textFileURL = textTxtURL
        } else {
            throw TextBundleError.missingTextFile
        }

        // Read markdown content
        guard let content = try? String(contentsOf: textFileURL, encoding: .utf8) else {
            throw TextBundleError.cannotReadContent
        }

        // Read info.json if present
        let infoURL = bundleURL.appendingPathComponent("info.json")
        var info: TextBundleInfo?
        if let infoData = try? Data(contentsOf: infoURL) {
            info = try? JSONDecoder().decode(TextBundleInfo.self, from: infoData)
        }

        // Assets path
        let assetsURL = bundleURL.appendingPathComponent("assets")
        let assetsPath: URL? = FileManager.default.fileExists(atPath: assetsURL.path) ? assetsURL : nil

        // Title from bundle name
        let title = bundleURL.deletingPathExtension().lastPathComponent

        return TextBundleContent(
            markdownContent: content,
            markdownFilePath: textFileURL.path,
            assetsPath: assetsPath,
            bundlePath: path,
            title: title,
            info: info,
            isTextPack: false,
            extractedPath: nil
        )
    }

    /// Load a compressed .textpack file
    private static func loadTextPack(path: String) throws -> TextBundleContent {
        let packURL = URL(fileURLWithPath: path)

        // Create temp directory for extraction
        let tempDir = NSTemporaryDirectory() + "marka-textpack-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
        let tempURL = URL(fileURLWithPath: tempDir)

        do {
            try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        } catch {
            throw TextBundleError.extractionFailed
        }

        // Extract the ZIP
        do {
            try extractZip(from: packURL, to: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw TextBundleError.extractionFailed
        }

        // Now load as a regular textbundle
        do {
            var content = try loadTextBundle(path: tempDir)
            // Mark as textpack and store extracted path for cleanup
            content = TextBundleContent(
                markdownContent: content.markdownContent,
                markdownFilePath: content.markdownFilePath,
                assetsPath: content.assetsPath,
                bundlePath: path,
                title: packURL.deletingPathExtension().lastPathComponent,
                info: content.info,
                isTextPack: true,
                extractedPath: tempDir
            )
            return content
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    /// Extract a ZIP file to a directory
    private static func extractZip(from source: URL, to destination: URL) throws {
        // Use Process to call unzip (simpler and more reliable than implementing ZIP parsing)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", source.path, "-d", destination.path]
        process.standardOutput = nil
        process.standardError = nil

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TextBundleError.invalidTextPack
        }
    }

    /// Clean up extracted textpack temp directory
    static func cleanup(content: TextBundleContent) {
        if let extractedPath = content.extractedPath {
            try? FileManager.default.removeItem(atPath: extractedPath)
        }
    }
}

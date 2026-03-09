import Foundation
import Compression

/// Reads TextPack files (.textpack compressed archives)
public enum TextPackReader {

    public static func read(at url: URL) throws -> TextBundleContent {
        // Create temp directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("textpack-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Extract the ZIP archive
        try extractZip(from: url, to: tempDir)

        // Find the textbundle directory inside
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )

        // Look for .textbundle directory or treat root as bundle
        let bundleURL: URL
        if let textbundleDir = contents.first(where: { $0.pathExtension == "textbundle" }) {
            bundleURL = textbundleDir
        } else {
            bundleURL = tempDir
        }

        // Read the extracted bundle
        return try TextBundleReader.read(at: bundleURL)
    }

    private static func extractZip(from sourceURL: URL, to destURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", sourceURL.path, "-d", destURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TextBundleError.extractionFailed
        }
    }
}

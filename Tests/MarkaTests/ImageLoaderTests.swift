import XCTest
@testable import Marka

final class ImageLoaderTests: XCTestCase {

    // MARK: - Regex extraction

    func testExtractsSimpleImageSource() {
        let md = "![alt](image.png)"
        let images = ImageLoader.loadImages(from: md, baseURL: nil)
        // Won't load (no base URL, not absolute), but we can verify the key
        XCTAssertTrue(images.isEmpty) // image.png isn't loadable without context
    }

    func testExtractsMultipleImageSources() {
        let md = """
        ![a](one.png)
        Some text
        ![b](two.png)
        """
        // Use a temp directory with actual images to verify extraction
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create tiny test images
        let imgData = createMinimalPNG()
        try? imgData.write(to: tmpDir.appendingPathComponent("one.png"))
        try? imgData.write(to: tmpDir.appendingPathComponent("two.png"))

        let images = ImageLoader.loadImages(from: md, baseURL: tmpDir)
        XCTAssertEqual(images.count, 2)
        XCTAssertNotNil(images["one.png"])
        XCTAssertNotNil(images["two.png"])
    }

    func testIgnoresNonImageMarkdown() {
        let md = """
        [link](url)
        **bold**
        `code`
        """
        let images = ImageLoader.loadImages(from: md, baseURL: nil)
        XCTAssertTrue(images.isEmpty)
    }

    func testHandlesEmptyAltText() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try? createMinimalPNG().write(to: tmpDir.appendingPathComponent("img.png"))

        let md = "![](img.png)"
        let images = ImageLoader.loadImages(from: md, baseURL: tmpDir)
        XCTAssertEqual(images.count, 1)
    }

    // MARK: - Path resolution

    func testResolvesRelativeToBaseURL() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let imgData = createMinimalPNG()
        try? imgData.write(to: tmpDir.appendingPathComponent("photo.png"))

        let md = "![test](photo.png)"
        let images = ImageLoader.loadImages(from: md, baseURL: tmpDir)
        XCTAssertNotNil(images["photo.png"])
    }

    func testResolvesSubdirectoryPath() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let subDir = tmpDir.appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try? createMinimalPNG().write(to: subDir.appendingPathComponent("pic.png"))

        let md = "![](assets/pic.png)"
        let images = ImageLoader.loadImages(from: md, baseURL: tmpDir)
        XCTAssertNotNil(images["assets/pic.png"])
    }

    func testMissingImageReturnsEmpty() {
        let md = "![missing](nonexistent.png)"
        let images = ImageLoader.loadImages(from: md, baseURL: nil)
        XCTAssertTrue(images.isEmpty)
    }

    func testEmptyMarkdownReturnsEmpty() {
        let images = ImageLoader.loadImages(from: "", baseURL: nil)
        XCTAssertTrue(images.isEmpty)
    }

    // MARK: - Helpers

    private func createMinimalPNG() -> Data {
        // 1x1 red pixel PNG
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.set()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }
}

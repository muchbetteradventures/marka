import AppKit

/// Loads images referenced in markdown, resolving relative paths against a base URL.
enum ImageLoader {
    /// Scan markdown for image references and load them.
    static func loadImages(from markdown: String, baseURL: URL?) -> [String: NSImage] {
        var images: [String: NSImage] = [:]

        // Simple regex to find markdown image sources: ![...](source)
        let pattern = #"!\[[^\]]*\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return images }

        let nsMarkdown = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let sourceRange = match.range(at: 1)
            let source = nsMarkdown.substring(with: sourceRange)

            if let image = loadImage(source: source, baseURL: baseURL) {
                images[source] = image
            }
        }

        return images
    }

    private static func loadImage(source: String, baseURL: URL?) -> NSImage? {
        // Try as absolute URL first
        if let url = URL(string: source), url.scheme == "http" || url.scheme == "https" {
            // Synchronous download (acceptable for initial render)
            if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
                return image
            }
            return nil
        }

        // Try as local path relative to baseURL
        if let baseURL = baseURL {
            let resolved = baseURL.appendingPathComponent(source)
            if let image = NSImage(contentsOf: resolved) {
                return image
            }
        }

        // Try as absolute file path
        if let image = NSImage(contentsOfFile: source) {
            return image
        }

        return nil
    }
}

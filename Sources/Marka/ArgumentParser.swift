import Foundation

struct ParsedArguments {
    let filePath: String
    let isTemp: Bool
    let title: String
    let baseURL: URL?
    let isChildProcess: Bool
    let tempFileToClean: String?
    // TextBundle support
    let isTextBundle: Bool
    let bundlePath: String?           // Original bundle path (for display)
    let extractedPath: String?        // For textpack: temp extraction directory to clean up
}

enum LaunchAction {
    case showHelp
    case showVersion
    case run(ParsedArguments)
}

enum ArgumentParser {
    static func parse() -> LaunchAction {
        let rawArgs = CommandLine.arguments
        let isChildProcess = rawArgs.contains("--marka-child")

        // Extract --marka-temp value from raw args (passed from parent process)
        var tempFileToClean: String?
        if let tempIdx = rawArgs.firstIndex(of: "--marka-temp"),
           tempIdx + 1 < rawArgs.count {
            tempFileToClean = rawArgs[tempIdx + 1]
        }

        // Filter out internal flags for user-facing argument parsing
        var filteredArgs = rawArgs.filter { $0 != "--marka-child" }
        if let tempIdx = filteredArgs.firstIndex(of: "--marka-temp") {
            if tempIdx + 1 < filteredArgs.count {
                filteredArgs.remove(at: tempIdx + 1)
            }
            filteredArgs.remove(at: tempIdx)
        }

        if filteredArgs.count > 1 {
            let rawPath = filteredArgs[1]

            if rawPath == "--help" || rawPath == "-h" {
                return .showHelp
            }

            if rawPath == "--version" || rawPath == "-v" {
                return .showVersion
            }

            let path: String
            if rawPath.hasPrefix("/") {
                path = rawPath
            } else {
                path = FileManager.default.currentDirectoryPath + "/" + rawPath
            }

            let url = URL(fileURLWithPath: path).standardized

            guard FileManager.default.fileExists(atPath: url.path) else {
                fputs("Error: File not found: \(url.path)\n", stderr)
                exit(1)
            }

            // Check if this is a TextBundle or TextPack
            if TextBundleHandler.isTextBundle(path: url.path) {
                do {
                    let bundle = try TextBundleHandler.load(path: url.path)
                    return .run(ParsedArguments(
                        filePath: bundle.markdownFilePath,
                        isTemp: bundle.isTextPack,  // TextPacks are extracted to temp
                        title: bundle.title,
                        baseURL: bundle.assetsPath ?? URL(fileURLWithPath: bundle.markdownFilePath).deletingLastPathComponent(),
                        isChildProcess: isChildProcess,
                        tempFileToClean: tempFileToClean,
                        isTextBundle: true,
                        bundlePath: bundle.bundlePath,
                        extractedPath: bundle.extractedPath
                    ))
                } catch {
                    fputs("Error: \(error.localizedDescription)\n", stderr)
                    exit(1)
                }
            }

            guard (try? String(contentsOf: url, encoding: .utf8)) != nil else {
                fputs("Error: Could not read file: \(url.path)\n", stderr)
                exit(1)
            }

            return .run(ParsedArguments(
                filePath: url.path,
                isTemp: tempFileToClean != nil,
                title: url.lastPathComponent,
                baseURL: url.deletingLastPathComponent(),
                isChildProcess: isChildProcess,
                tempFileToClean: tempFileToClean,
                isTextBundle: false,
                bundlePath: nil,
                extractedPath: nil
            ))

        } else if let content = StdinReader.readAll() {
            let tempFile = NSTemporaryDirectory() + "marka-stdin-\(ProcessInfo.processInfo.processIdentifier).md"
            try? content.write(toFile: tempFile, atomically: true, encoding: .utf8)

            return .run(ParsedArguments(
                filePath: tempFile,
                isTemp: true,
                title: "Marka (stdin)",
                baseURL: nil,
                isChildProcess: isChildProcess,
                tempFileToClean: tempFileToClean,
                isTextBundle: false,
                bundlePath: nil,
                extractedPath: nil
            ))

        } else {
            return .showHelp
        }
    }

    static func printUsage() {
        let usage = """
        Usage: marka <file.md>
               marka <file.textbundle>
               marka <file.textpack>
               command | marka

        A lightweight Markdown viewer for the terminal.

        Supported formats:
          .md           Markdown files
          .textbundle   TextBundle packages (with images)
          .textpack     Compressed TextBundle archives

        Examples:
          marka README.md
          marka ~/notes/todo.md
          marka recipe.textbundle
          marka document.textpack
          cat notes.md | marka
          echo "# Hello" | marka
        """
        print(usage)
    }
}

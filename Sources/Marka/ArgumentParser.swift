import Foundation

struct ParsedArguments {
    let filePath: String
    let isTemp: Bool
    let title: String
    let baseURL: URL?
    let isChildProcess: Bool
    let tempFileToClean: String?
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
                tempFileToClean: tempFileToClean
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
                tempFileToClean: tempFileToClean
            ))

        } else {
            return .showHelp
        }
    }

    static func printUsage() {
        let usage = """
        Usage: marka <file.md>
               command | marka

        A lightweight Markdown viewer for the terminal.

        Examples:
          marka README.md
          marka ~/notes/todo.md
          cat notes.md | marka
          echo "# Hello" | marka
        """
        print(usage)
    }
}

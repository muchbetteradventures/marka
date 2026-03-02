import AppKit
import Foundation

let document = MarkdownDocument()
var fileWatcher: FileWatcher?

// --- Input handling ---

let args = CommandLine.arguments

if args.count > 1 {
    // File mode
    let rawPath = args[1]

    if rawPath == "--help" || rawPath == "-h" {
        printUsage()
        exit(0)
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

    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Error: Could not read file: \(url.path)\n", stderr)
        exit(1)
    }

    document.markdown = content
    document.title = url.lastPathComponent
    document.baseURL = url.deletingLastPathComponent()

    // Set up file watcher
    fileWatcher = FileWatcher(path: url.path) { newContent in
        document.markdown = newContent
    }
    fileWatcher?.start()

} else if let stdinContent = StdinReader.readAll() {
    // Stdin mode
    document.markdown = stdinContent
    document.title = "Markie (stdin)"

} else {
    printUsage()
    exit(1)
}

// --- App bootstrap ---

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = AppDelegate(document: document)
app.delegate = delegate
app.run()

// --- Helpers ---

func printUsage() {
    let usage = """
    Usage: markie <file.md>
           command | markie

    A lightweight Markdown viewer for the terminal.

    Examples:
      markie README.md
      markie ~/notes/todo.md
      cat notes.md | markie
      echo "# Hello" | markie
    """
    print(usage)
}

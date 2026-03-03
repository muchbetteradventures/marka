import AppKit
import Foundation

let isChildProcess = CommandLine.arguments.contains("--markie-child")
nonisolated(unsafe) var _tempFileForCleanup: UnsafeMutablePointer<CChar>?

// --- Input handling ---

let document = MarkdownDocument()
var fileWatcher: FileWatcher?

var filteredArgs = CommandLine.arguments.filter { $0 != "--markie-child" }

if filteredArgs.count > 1 {
    // File mode
    let rawPath = filteredArgs[1]

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

} else if let stdinContent = StdinReader.readAll() {
    // Stdin mode
    document.markdown = stdinContent
    document.title = "Markie (stdin)"

} else {
    printUsage()
    exit(1)
}

// --- Detach from terminal ---

if !isChildProcess {
    // Re-launch ourselves as a detached child process
    let execPath = ProcessInfo.processInfo.arguments[0].hasPrefix("/")
        ? ProcessInfo.processInfo.arguments[0]
        : URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardized.path

    // Build args: original args + sentinel + for stdin mode, pass content via temp file
    var childArgs = filteredArgs
    childArgs.append("--markie-child")

    // If stdin mode, write content to a temp file and pass that instead
    if filteredArgs.count <= 1 {
        let tempFile = NSTemporaryDirectory() + "markie-stdin-\(ProcessInfo.processInfo.processIdentifier).md"
        try? document.markdown.write(toFile: tempFile, atomically: true, encoding: .utf8)
        childArgs = [filteredArgs[0], tempFile, "--markie-child", "--markie-temp", tempFile]
    }

    var pid: pid_t = 0
    let argv = ([execPath] + childArgs.dropFirst()).map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }

    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)
    // Detach stdin/stdout/stderr so terminal isn't held
    posix_spawn_file_actions_addopen(&fileActions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&fileActions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0)
    posix_spawn_file_actions_addopen(&fileActions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)
    defer { posix_spawn_file_actions_destroy(&fileActions) }

    var attrs: posix_spawnattr_t?
    posix_spawnattr_init(&attrs)
    posix_spawnattr_setflags(&attrs, Int16(POSIX_SPAWN_SETPGROUP))
    posix_spawnattr_setpgroup(&attrs, 0)
    defer { posix_spawnattr_destroy(&attrs) }

    let result = posix_spawn(&pid, execPath, &fileActions, &attrs, argv, environ)
    if result != 0 {
        fputs("Error: could not launch viewer (errno \(result))\n", stderr)
        exit(1)
    }

    _exit(0)
}

// --- Child process: clean up temp file on exit if needed ---

var tempFileToClean: String?
if let tempIdx = CommandLine.arguments.firstIndex(of: "--markie-temp"),
   tempIdx + 1 < CommandLine.arguments.count {
    tempFileToClean = CommandLine.arguments[tempIdx + 1]
}

// Start file watcher (only for real files, not temp stdin files)
if filteredArgs.count > 1, tempFileToClean == nil {
    let rawPath = filteredArgs[1]
    let path: String
    if rawPath.hasPrefix("/") {
        path = rawPath
    } else {
        path = FileManager.default.currentDirectoryPath + "/" + rawPath
    }
    let url = URL(fileURLWithPath: path).standardized

    fileWatcher = FileWatcher(path: url.path) { newContent in
        document.markdown = newContent
    }
    fileWatcher?.start()
}

// --- App bootstrap ---

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = AppDelegate(document: document)
app.delegate = delegate

// Clean temp file when app terminates
if let tempFile = tempFileToClean {
    _tempFileForCleanup = strdup(tempFile)
    atexit {
        if let p = _tempFileForCleanup {
            unlink(p)
            free(p)
        }
    }
}

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

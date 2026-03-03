import AppKit
import Foundation

let isChildProcess = CommandLine.arguments.contains("--marka-child")
nonisolated(unsafe) var _tempFileForCleanup: UnsafeMutablePointer<CChar>?

// --- Input handling ---

var filteredArgs = CommandLine.arguments.filter { $0 != "--marka-child" }
if let tempIdx = filteredArgs.firstIndex(of: "--marka-temp") {
    // Remove --marka-temp and the value after it
    if tempIdx + 1 < filteredArgs.count {
        filteredArgs.remove(at: tempIdx + 1)
    }
    filteredArgs.remove(at: tempIdx)
}

var filePath: String?
var isTemp = false
var title = "Marka (stdin)"
var baseURL: URL?
var stdinContent: String?

if filteredArgs.count > 1 {
    // File mode
    let rawPath = filteredArgs[1]

    if rawPath == "--help" || rawPath == "-h" {
        printUsage()
        exit(0)
    }

    if rawPath == "--version" || rawPath == "-v" {
        print("marka \(markaVersion)")
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

    guard (try? String(contentsOf: url, encoding: .utf8)) != nil else {
        fputs("Error: Could not read file: \(url.path)\n", stderr)
        exit(1)
    }

    filePath = url.path
    title = url.lastPathComponent
    baseURL = url.deletingLastPathComponent()

} else if let content = StdinReader.readAll() {
    // Stdin mode: write temp file now so it's available for IPC or child
    stdinContent = content
    let tempFile = NSTemporaryDirectory() + "marka-stdin-\(ProcessInfo.processInfo.processIdentifier).md"
    try? content.write(toFile: tempFile, atomically: true, encoding: .utf8)
    filePath = tempFile
    isTemp = true
    title = "Marka (stdin)"

} else {
    printUsage()
    exit(1)
}

// --- Check for temp file passed from parent process ---

var tempFileToClean: String?
if let tempIdx = CommandLine.arguments.firstIndex(of: "--marka-temp"),
   tempIdx + 1 < CommandLine.arguments.count {
    tempFileToClean = CommandLine.arguments[tempIdx + 1]
    isTemp = true
}

// --- IPC: try handing off to running instance ---

if !isChildProcess, let path = filePath {
    let payload = IPCPayload(
        path: path,
        isTemp: isTemp,
        title: title,
        baseURL: baseURL?.absoluteString
    )

    if sendToRunningInstance(payload: payload) {
        _exit(0)
    }
}

// --- Detach from terminal ---

if !isChildProcess {
    let execPath = ProcessInfo.processInfo.arguments[0].hasPrefix("/")
        ? ProcessInfo.processInfo.arguments[0]
        : URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardized.path

    // Build args: executable path + file path + sentinel
    var childArgs = [execPath]
    if let path = filePath {
        childArgs.append(path)
    }
    childArgs.append("--marka-child")
    if isTemp, let path = filePath {
        childArgs.append("--marka-temp")
        childArgs.append(path)
    }

    var pid: pid_t = 0
    let argv = childArgs.map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }

    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)
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

// --- Child process: app bootstrap ---

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let initialPayload = IPCPayload(
    path: filePath ?? "",
    isTemp: isTemp || tempFileToClean != nil,
    title: title,
    baseURL: baseURL?.absoluteString
)

let delegate = AppDelegate(initialDocument: initialPayload)
app.delegate = delegate

// Clean temp file when app terminates
let tempFile = tempFileToClean ?? (isTemp ? filePath : nil)
if let tempFile {
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

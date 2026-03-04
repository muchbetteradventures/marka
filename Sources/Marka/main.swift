import AppKit
import Foundation

nonisolated(unsafe) var _tempFileForCleanup: UnsafeMutablePointer<CChar>?

// --- Parse arguments ---

switch ArgumentParser.parse() {
case .showHelp:
    ArgumentParser.printUsage()
    exit(0)

case .showVersion:
    print("marka \(markaVersion)")
    exit(0)

case .run(let args):
    // --- IPC: try handing off to running instance ---

    if !args.isChildProcess {
        let payload = IPCPayload(
            path: args.filePath,
            isTemp: args.isTemp,
            title: args.title,
            baseURL: args.baseURL?.absoluteString
        )

        if sendToRunningInstance(payload: payload) {
            _exit(0)
        }
    }

    // --- Detach from terminal ---

    if !args.isChildProcess {
        let execPath = ProcessInfo.processInfo.arguments[0].hasPrefix("/")
            ? ProcessInfo.processInfo.arguments[0]
            : URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardized.path

        // Build args: executable path + file path + sentinel
        var childArgs = [execPath, args.filePath, "--marka-child"]
        if args.isTemp {
            childArgs.append("--marka-temp")
            childArgs.append(args.filePath)
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
        path: args.filePath,
        isTemp: args.isTemp || args.tempFileToClean != nil,
        title: args.title,
        baseURL: args.baseURL?.absoluteString
    )

    let delegate = AppDelegate(initialDocument: initialPayload)
    app.delegate = delegate

    // Clean temp file when app terminates
    let tempFile = args.tempFileToClean ?? (args.isTemp ? args.filePath : nil)
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
}

import Foundation

@MainActor
final class FileWatcher {
    private let path: String
    private let onChange: @MainActor (String) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init(path: String, onChange: @escaping @MainActor (String) -> Void) {
        self.path = path
        self.onChange = onChange
    }

    deinit {
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    func start() {
        watch()
    }

    func stop() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func watch() {
        stop()

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let events: DispatchSource.FileSystemEvent = [.write, .delete, .rename, .revoke]
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: events,
            queue: .main
        )

        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let event = src.data

                if event.contains(.delete) || event.contains(.rename) || event.contains(.revoke) {
                    // File was replaced (atomic save). Re-establish watcher after a brief delay.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        MainActor.assumeIsolated {
                            self.watch()
                            self.readAndNotify()
                        }
                    }
                } else {
                    self.readAndNotify()
                }
            }
        }

        src.setCancelHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.fileDescriptor >= 0 {
                    close(self.fileDescriptor)
                    self.fileDescriptor = -1
                }
            }
        }

        source = src
        src.resume()
    }

    private func readAndNotify() {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        onChange(content)
    }
}

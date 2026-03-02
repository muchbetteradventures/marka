import Foundation

enum StdinReader {
    static func readAll() -> String? {
        guard isatty(STDIN_FILENO) == 0 else { return nil }

        var data = Data()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = read(STDIN_FILENO, buffer, bufferSize)
            if bytesRead <= 0 { break }
            data.append(buffer, count: bytesRead)
        }

        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

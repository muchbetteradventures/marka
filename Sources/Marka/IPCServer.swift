import Foundation

private nonisolated(unsafe) let portName = "com.marka.viewer.ipc" as CFString

/// Payload sent over IPC to open a document in the running instance.
struct IPCPayload: Codable {
    let path: String
    let isTemp: Bool
    let title: String
    let baseURL: String?
}

/// Attempts to send a document payload to an already-running marka instance.
/// Returns true if the message was delivered successfully.
func sendToRunningInstance(payload: IPCPayload) -> Bool {
    guard let remote = CFMessagePortCreateRemote(nil, portName) else {
        return false
    }

    guard let jsonData = try? JSONEncoder().encode(payload) else {
        return false
    }

    let status = CFMessagePortSendRequest(
        remote,
        0,                          // message ID
        jsonData as CFData,
        2.0,                        // send timeout
        0,                          // receive timeout (no reply expected)
        nil,                        // reply mode
        nil                         // reply data
    )

    return status == kCFMessagePortSuccess
}

/// Listens for IPC messages from new marka invocations.
@MainActor
final class IPCServer {
    private var port: CFMessagePort?
    var onOpenDocument: ((IPCPayload) -> Void)?

    func start() {
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        port = CFMessagePortCreateLocal(
            nil,
            portName,
            { (_, _, data, info) -> Unmanaged<CFData>? in
                guard let info, let data else { return nil }
                let server = Unmanaged<IPCServer>.fromOpaque(info).takeUnretainedValue()
                let jsonData = data as Data
                guard let payload = try? JSONDecoder().decode(IPCPayload.self, from: jsonData) else {
                    return nil
                }
                MainActor.assumeIsolated {
                    server.onOpenDocument?(payload)
                }
                return nil
            },
            &context,
            nil
        )

        guard let port else { return }

        let source = CFMessagePortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }
}

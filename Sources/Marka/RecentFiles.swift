import Foundation

/// Manages a list of recently opened files, persisted in UserDefaults.
@MainActor
final class RecentFiles {
    static let shared = RecentFiles()
    private let key = "recentFiles"
    private let maxCount = 10

    struct Entry: Codable {
        let path: String
        let title: String
        let baseURL: String?
        let isTextBundle: Bool
        let bundlePath: String?
    }

    var entries: [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return list
    }

    func add(_ payload: IPCPayload) {
        var list = entries

        // Use bundlePath for TextBundles, otherwise the file path
        let identifier = payload.bundlePath ?? payload.path

        // Remove existing entry with same path
        list.removeAll { ($0.bundlePath ?? $0.path) == identifier }

        // Add to front
        let entry = Entry(
            path: payload.bundlePath ?? payload.path,
            title: payload.title,
            baseURL: payload.baseURL,
            isTextBundle: payload.isTextBundle,
            bundlePath: payload.bundlePath
        )
        list.insert(entry, at: 0)

        // Trim
        if list.count > maxCount {
            list = Array(list.prefix(maxCount))
        }

        save(list)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func save(_ list: [Entry]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

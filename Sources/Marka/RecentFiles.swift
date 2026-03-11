import Foundation

/// Manages a list of recently opened files, persisted in UserDefaults.
@MainActor
final class RecentFiles {
    static let shared = RecentFiles()
    private let defaults: UserDefaults
    private let key = "recentFiles"
    let maxCount = 10

    struct Entry: Codable, Equatable {
        let path: String
        let title: String
        let baseURL: String?
        let isTextBundle: Bool
        let bundlePath: String?
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var entries: [Entry] {
        guard let data = defaults.data(forKey: key),
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
            path: identifier,
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
        defaults.removeObject(forKey: key)
    }

    private func save(_ list: [Entry]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }
}

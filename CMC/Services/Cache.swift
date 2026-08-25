import Foundation

/// A JSON file in Application Support holding the last good result for a screen.
///
/// Every screen caches (PLAN §3.4): a broken site must degrade to stale data
/// with a visible "última atualização", never to an empty screen.
nonisolated struct Cache<Value: Codable> {

    /// What was stored, and when.
    struct Entry: Codable {
        var value: Value
        var savedAt: Date
    }

    let filename: String

    init(_ filename: String) {
        self.filename = filename
    }

    private var url: URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let folder = directory.appendingPathComponent("CMC", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(filename)
    }

    /// Never throws: a missing or unreadable cache is simply "no cache". A
    /// stale file left over from an older model version must not break launch.
    func load() -> Entry? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Entry.self, from: data)
    }

    @discardableResult
    func save(_ value: Value, at date: Date = Date()) -> Bool {
        guard let url else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Entry(value: value, savedAt: date)) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

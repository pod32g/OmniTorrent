import Foundation

public struct Persistence: Sendable {
    private let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    public static var appSupport: Persistence {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OmniTorrent")
        return Persistence(baseDirectory: dir)
    }

    private var settingsURL: URL { baseDirectory.appendingPathComponent("settings.json") }

    public func saveSettings(_ settings: EngineSettings) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func loadSettings() throws -> EngineSettings {
        let data = try Data(contentsOf: settingsURL)
        return try JSONDecoder().decode(EngineSettings.self, from: data)
    }

    public func loadSettingsOrDefaults() -> EngineSettings {
        (try? loadSettings()) ?? .defaults
    }

    private var resumeDirectory: URL { baseDirectory.appendingPathComponent("resume") }

    public func saveResumeData(_ data: Data, for id: TorrentID) throws {
        try FileManager.default.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
        let fileURL = resumeDirectory.appendingPathComponent("\(id.uuidString).resume")
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadResumeData(for id: TorrentID) throws -> Data {
        let fileURL = resumeDirectory.appendingPathComponent("\(id.uuidString).resume")
        return try Data(contentsOf: fileURL)
    }

    public func allResumeDataFiles() -> [(id: TorrentID, url: URL)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: resumeDirectory, includingPropertiesForKeys: nil) else { return [] }
        return contents.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            guard let id = TorrentID(uuidString: name) else { return nil }
            return (id, url)
        }
    }

    public func deleteResumeData(for id: TorrentID) throws {
        let fileURL = resumeDirectory.appendingPathComponent("\(id.uuidString).resume")
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Torrent Options

    private var optionsDirectory: URL {
        baseDirectory.appendingPathComponent("options")
    }

    public func saveOptions(_ options: TorrentOptions, for id: TorrentID) throws {
        try FileManager.default.createDirectory(at: optionsDirectory, withIntermediateDirectories: true)
        let fileURL = optionsDirectory.appendingPathComponent("\(id.uuidString).json")
        let data = try JSONEncoder().encode(options)
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadOptions(for id: TorrentID) -> TorrentOptions {
        let fileURL = optionsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL),
              let options = try? JSONDecoder().decode(TorrentOptions.self, from: data) else {
            return TorrentOptions()
        }
        return options
    }

    public func deleteOptions(for id: TorrentID) throws {
        let fileURL = optionsDirectory.appendingPathComponent("\(id.uuidString).json")
        try FileManager.default.removeItem(at: fileURL)
    }

    public func allOptionFiles() -> [(id: TorrentID, options: TorrentOptions)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: optionsDirectory, includingPropertiesForKeys: nil) else { return [] }
        return contents.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            guard let id = TorrentID(uuidString: name),
                  let data = try? Data(contentsOf: url),
                  let options = try? JSONDecoder().decode(TorrentOptions.self, from: data) else { return nil }
            return (id, options)
        }
    }

    // MARK: - RSS Feeds

    private var feedsURL: URL { baseDirectory.appendingPathComponent("feeds.json") }

    public func saveFeeds(_ feeds: [RSSFeed]) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(feeds)
        try data.write(to: feedsURL, options: .atomic)
    }

    public func loadFeeds() -> [RSSFeed] {
        guard let data = try? Data(contentsOf: feedsURL),
              let feeds = try? JSONDecoder().decode([RSSFeed].self, from: data) else {
            return []
        }
        return feeds
    }
}

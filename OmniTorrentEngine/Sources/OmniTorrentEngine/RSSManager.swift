import Foundation

public actor RSSManager {
    private var feeds: [RSSFeed]
    private let persistence: Persistence
    private let onTorrentFound: @Sendable (TorrentSource) async -> Void
    private var pollingTask: Task<Void, Never>?

    public init(feeds: [RSSFeed], persistence: Persistence, onTorrentFound: @escaping @Sendable (TorrentSource) async -> Void) {
        self.feeds = feeds
        self.persistence = persistence
        self.onTorrentFound = onTorrentFound
    }

    public func start() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkAllFeeds()
                try? await Task.sleep(for: .seconds(60)) // Check every minute if any feed is due
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func updateFeeds(_ newFeeds: [RSSFeed]) {
        feeds = newFeeds
        try? persistence.saveFeeds(feeds)
    }

    public func getFeeds() -> [RSSFeed] {
        feeds
    }

    private func checkAllFeeds() async {
        let now = Date()
        for i in feeds.indices {
            let feed = feeds[i]
            let interval = TimeInterval(feed.refreshInterval * 60)
            if let lastChecked = feed.lastChecked, now.timeIntervalSince(lastChecked) < interval {
                continue
            }
            await checkFeed(at: i)
        }
    }

    private func checkFeed(at index: Int) async {
        var feed = feeds[index]
        guard let url = URL(string: feed.url) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = RSSParser()
            let items = parser.parse(data: data)

            for item in items {
                guard !feed.seenGUIDs.contains(item.guid) else { continue }

                // Apply filter if set
                if let pattern = feed.filterPattern, !pattern.isEmpty {
                    guard item.title.range(of: pattern, options: .regularExpression) != nil else {
                        feed.seenGUIDs.insert(item.guid)
                        continue
                    }
                }

                // Add the torrent
                if let magnetURI = item.magnetURI {
                    await onTorrentFound(.magnet(magnetURI))
                } else if let torrentURL = item.torrentURL, let url = URL(string: torrentURL) {
                    // Download the .torrent file to temp
                    if let (fileData, _) = try? await URLSession.shared.data(from: url) {
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString + ".torrent")
                        try? fileData.write(to: tempURL)
                        await onTorrentFound(.file(tempURL))
                    }
                }

                feed.seenGUIDs.insert(item.guid)
            }

            feed.lastChecked = Date()
            feeds[index] = feed
            try? persistence.saveFeeds(feeds)
        } catch {
            // Network error — skip, will retry next cycle
        }
    }
}

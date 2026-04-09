import Foundation

public struct RSSFeed: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var url: String
    public var refreshInterval: Int  // minutes, default 30
    public var filterPattern: String?  // regex pattern to match titles, nil = match all
    public var lastChecked: Date?
    public var seenGUIDs: Set<String>  // GUIDs of items already processed

    public init(id: UUID = UUID(), name: String, url: String, refreshInterval: Int = 30, filterPattern: String? = nil, lastChecked: Date? = nil, seenGUIDs: Set<String> = []) {
        self.id = id
        self.name = name
        self.url = url
        self.refreshInterval = refreshInterval
        self.filterPattern = filterPattern
        self.lastChecked = lastChecked
        self.seenGUIDs = seenGUIDs
    }
}

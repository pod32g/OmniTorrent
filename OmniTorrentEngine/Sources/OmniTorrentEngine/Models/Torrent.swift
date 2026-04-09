import Foundation

public typealias TorrentID = UUID

public enum TorrentState: Sendable, Equatable {
    case checking, downloading, seeding, paused, queued, error

    public static func from(ltState: Int, isPaused: Bool) -> TorrentState {
        if isPaused { return .paused }
        switch ltState {
        case 1, 2: return .checking
        case 3: return .downloading
        case 4: return .downloading
        case 5: return .seeding
        default: return .queued
        }
    }
}

public struct Torrent: Identifiable, Sendable {
    public let id: TorrentID
    public var name: String
    public var state: TorrentState
    public var progress: Float
    public var totalSize: Int64
    public var savePath: String
    public var files: [FileEntry]
    public var stats: TransferStats
    public var infoHash: String

    public init(id: TorrentID = TorrentID(), name: String, state: TorrentState = .queued, progress: Float = 0, totalSize: Int64 = 0, savePath: String = "", files: [FileEntry] = [], stats: TransferStats = .zero, infoHash: String = "") {
        self.id = id; self.name = name; self.state = state; self.progress = progress
        self.totalSize = totalSize; self.savePath = savePath; self.files = files
        self.stats = stats; self.infoHash = infoHash
    }
}

import Foundation

public enum TorrentTag: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case red
    case orange
    case yellow
    case green
    case blue
    case purple

    public var id: String { rawValue }
}

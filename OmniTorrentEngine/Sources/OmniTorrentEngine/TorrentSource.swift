import Foundation

public enum TorrentSource: Sendable {
    case magnet(String)
    case file(URL)
}

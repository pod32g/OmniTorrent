import AppKit
import OmniTorrentEngine

@MainActor
enum DockProgress {
    static func update(torrents: [Torrent]) {
        let downloading = torrents.filter { $0.state == .downloading }

        guard !downloading.isEmpty else {
            NSApp?.dockTile.badgeLabel = nil
            NSApp?.dockTile.display()
            return
        }

        let totalProgress = downloading.reduce(Float(0)) { $0 + $1.progress } / Float(downloading.count)
        let pct = Int(totalProgress * 100)
        NSApp?.dockTile.badgeLabel = "\(pct)%"
        NSApp?.dockTile.display()
    }
}

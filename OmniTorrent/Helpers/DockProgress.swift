import AppKit
import OmniTorrentEngine

enum DockProgress {
    static func update(torrents: [Torrent]) {
        let downloading = torrents.filter { $0.state == .downloading }

        guard !downloading.isEmpty else {
            // Clear badge when nothing is downloading
            NSApp.dockTile.contentView = nil
            NSApp.dockTile.badgeLabel = nil
            NSApp.dockTile.display()
            return
        }

        // Calculate overall progress across all downloading torrents
        let totalProgress = downloading.reduce(Float(0)) { $0 + $1.progress } / Float(downloading.count)

        // Set badge label with percentage
        NSApp.dockTile.badgeLabel = "\(Int(totalProgress * 100))%"
        NSApp.dockTile.display()
    }
}

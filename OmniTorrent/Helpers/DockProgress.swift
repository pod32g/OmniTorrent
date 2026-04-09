import AppKit
import OmniTorrentEngine

class DockProgressView: NSView {
    var progress: Float = 0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the app icon
        if let icon = NSApp?.applicationIconImage {
            icon.draw(in: bounds)
        }

        // Draw progress bar at the bottom
        let barHeight: CGFloat = 12
        let barInset: CGFloat = 8
        let barRect = NSRect(
            x: barInset,
            y: barInset,
            width: bounds.width - barInset * 2,
            height: barHeight
        )

        // Background
        let bgPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        NSColor.black.withAlphaComponent(0.6).setFill()
        bgPath.fill()

        // Fill
        let fillWidth = (barRect.width - 4) * CGFloat(progress)
        let fillRect = NSRect(
            x: barRect.origin.x + 2,
            y: barRect.origin.y + 2,
            width: fillWidth,
            height: barHeight - 4
        )
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: (barHeight - 4) / 2, yRadius: (barHeight - 4) / 2)
        NSColor.systemBlue.setFill()
        fillPath.fill()
    }
}

@MainActor
enum DockProgress {
    private static var progressView: DockProgressView?

    static func update(torrents: [Torrent]) {
        let downloading = torrents.filter { $0.state == .downloading }

        guard !downloading.isEmpty else {
            // Clear
            if progressView != nil {
                NSApplication.shared.dockTile.contentView = nil
                NSApplication.shared.dockTile.badgeLabel = nil
                NSApplication.shared.dockTile.display()
                progressView = nil
            }
            return
        }

        let totalProgress = downloading.reduce(Float(0)) { $0 + $1.progress } / Float(downloading.count)

        // Create or update the progress view
        let tileSize = NSApplication.shared.dockTile.size
        if progressView == nil {
            let view = DockProgressView(frame: NSRect(origin: .zero, size: tileSize))
            progressView = view
            NSApplication.shared.dockTile.contentView = view
        }

        progressView?.progress = totalProgress
        NSApplication.shared.dockTile.badgeLabel = "\(Int(totalProgress * 100))%"
        NSApplication.shared.dockTile.display()
    }
}

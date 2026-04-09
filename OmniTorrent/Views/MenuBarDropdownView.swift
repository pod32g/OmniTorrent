import SwiftUI
import OmniTorrentEngine

struct MenuBarDropdownView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Speed summary
            HStack(spacing: 16) {
                Text("\u{2193} \(FormatHelpers.formatRate(viewModel.globalStats.downloadRate))")
                Text("\u{2191} \(FormatHelpers.formatRate(viewModel.globalStats.uploadRate))")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Active torrents (max 5)
            let active = viewModel.torrents.prefix(5)
            ForEach(active) { torrent in
                HStack {
                    Text(torrent.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(FormatHelpers.formatProgress(torrent.progress))
                        .foregroundStyle(.secondary)
                    Text(torrent.state.label)
                        .foregroundStyle(torrent.state.color)
                        .font(.caption)
                }
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            if viewModel.torrents.count > 5 {
                Text("and \(viewModel.torrents.count - 5) more...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }

            if viewModel.torrents.isEmpty {
                Text("No active torrents")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            Divider()

            Button("Show OmniTorrent") {
                NSApp.activate(ignoringOtherApps: true)
                if NSApp.windows.filter({ $0.isVisible && !$0.title.isEmpty }).isEmpty {
                    // Re-open main window if none visible
                    NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(width: 300)
    }
}

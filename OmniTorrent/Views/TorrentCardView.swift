import SwiftUI
import OmniTorrentEngine

struct TorrentCardView: View {
    let torrent: Torrent
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(torrent.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(torrent.state.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(torrent.state.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(torrent.state.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 16) {
                Text(FormatHelpers.formatBytes(torrent.totalSize))

                if torrent.state == .downloading {
                    Text("\u{00B7} \(FormatHelpers.formatProgress(torrent.progress))")
                    Text("\u{2193} \(FormatHelpers.formatRate(torrent.stats.downloadRate))")
                    Text("ETA \(FormatHelpers.formatETA(torrent.stats.eta))")
                } else if torrent.state == .seeding {
                    Text("\u{2191} \(FormatHelpers.formatRate(torrent.stats.uploadRate))")
                    Text("Ratio: \(FormatHelpers.formatRatio(uploaded: torrent.stats.totalUploaded, downloaded: torrent.stats.totalDownloaded))")
                }

                Text("\(torrent.stats.peersConnected) peers")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            ProgressView(value: torrent.progress)
                .tint(torrent.state.color)
                .scaleEffect(y: 0.5)
        }
        .padding(14)
        .glassCard(isSelected: isSelected)
        .contextMenu {
            TorrentContextMenu(torrent: torrent)
        }
    }
}

extension View {
    @ViewBuilder
    func glassCard(isSelected: Bool) -> some View {
        if #available(macOS 26, *) {
            self
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: 14)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                    }
                }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                    }
                }
        }
    }
}

struct TorrentContextMenu: View {
    let torrent: Torrent

    @Environment(TorrentListViewModel.self) private var viewModel

    var body: some View {
        if torrent.state == .paused {
            Button("Resume") { viewModel.resumeTorrent(torrent.id) }
        } else {
            Button("Pause") { viewModel.pauseTorrent(torrent.id) }
        }

        Divider()

        Toggle("Sequential Download", isOn: Binding(
            get: { false },
            set: { viewModel.setSequentialDownload(torrent.id, enabled: $0) }
        ))

        Menu("Download Limit") {
            Button("Unlimited") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 0) }
            Button("100 KB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 100_000) }
            Button("500 KB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 500_000) }
            Button("1 MB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 1_000_000) }
            Button("5 MB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 5_000_000) }
        }

        Menu("Upload Limit") {
            Button("Unlimited") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 0) }
            Button("100 KB/s") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 100_000) }
            Button("500 KB/s") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 500_000) }
            Button("1 MB/s") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 1_000_000) }
        }

        Divider()

        Menu("On Complete") {
            Button("Do Nothing") { updateCompletionAction(.doNothing) }
            Button("Open File") { updateCompletionAction(.openFile) }
            Button("Reveal in Finder") { updateCompletionAction(.revealInFinder) }
            Divider()
            Button("Move To...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        Task { @MainActor in
                            var options = await viewModel.torrentOptions(for: torrent.id)
                            options.moveToPath = url.path
                            viewModel.setTorrentOptions(options, for: torrent.id)
                        }
                    }
                }
            }
            Button("Don't Move") {
                Task { @MainActor in
                    var options = await viewModel.torrentOptions(for: torrent.id)
                    options.moveToPath = nil
                    viewModel.setTorrentOptions(options, for: torrent.id)
                }
            }
        }

        Divider()

        Button("Reveal in Finder") {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: torrent.savePath)
        }

        Divider()

        Button("Remove", role: .destructive) {
            viewModel.removeTorrent(torrent.id)
        }
        Button("Remove & Delete Files", role: .destructive) {
            viewModel.removeTorrent(torrent.id, deleteFiles: true)
        }
    }

    private func updateCompletionAction(_ action: CompletionAction) {
        Task { @MainActor in
            var options = await viewModel.torrentOptions(for: torrent.id)
            options.completionAction = action
            viewModel.setTorrentOptions(options, for: torrent.id)
        }
    }
}

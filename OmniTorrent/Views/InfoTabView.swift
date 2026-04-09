import SwiftUI
import OmniTorrentEngine

struct InfoTabView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        if let torrent = viewModel.selectedTorrent {
            Form {
                LabeledContent("Name", value: torrent.name)
                LabeledContent("Info Hash", value: torrent.infoHash)
                LabeledContent("Total Size", value: FormatHelpers.formatBytes(torrent.totalSize))
                LabeledContent("Save Path", value: torrent.savePath)
                LabeledContent("Progress", value: FormatHelpers.formatProgress(torrent.progress))
                LabeledContent("State", value: torrent.state.label)
                LabeledContent("Downloaded", value: FormatHelpers.formatBytes(torrent.stats.totalDownloaded))
                LabeledContent("Uploaded", value: FormatHelpers.formatBytes(torrent.stats.totalUploaded))
                LabeledContent("Peers", value: "\(torrent.stats.peersConnected)")
            }
            .font(.system(size: 12))
            .padding()
        }
    }
}

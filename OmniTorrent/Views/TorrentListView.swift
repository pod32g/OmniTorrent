import SwiftUI
import OmniTorrentEngine

struct TorrentListView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        ScrollView {
            if #available(macOS 26, *) {
                GlassEffectContainer(spacing: 8) {
                    torrentStack
                }
            } else {
                torrentStack
            }
        }
        .overlay {
            if viewModel.filteredTorrents.isEmpty {
                ContentUnavailableView {
                    Label("No Torrents", systemImage: "arrow.down.circle.dotted")
                } description: {
                    Text("Drop a .torrent file or paste a magnet link to get started.")
                }
            }
        }
        .environment(viewModel)
    }

    private var torrentStack: some View {
        LazyVStack(spacing: 6) {
            ForEach(viewModel.filteredTorrents) { torrent in
                TorrentCardView(
                    torrent: torrent,
                    isSelected: viewModel.selectedTorrentID == torrent.id
                )
                .onTapGesture {
                    viewModel.selectedTorrentID = torrent.id
                }
            }
        }
        .padding(10)
    }
}

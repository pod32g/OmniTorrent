import SwiftUI
import OmniTorrentEngine

struct PeersTabView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var peers: [Peer] = []

    var body: some View {
        Table(peers) {
            TableColumn("IP") { peer in
                Text(peer.ip).font(.system(size: 11, design: .monospaced))
            }
            .width(min: 100, ideal: 140)

            TableColumn("Client") { peer in
                Text(peer.client).font(.system(size: 11))
            }
            .width(min: 80, ideal: 120)

            TableColumn("\u{2193}") { peer in
                Text(FormatHelpers.formatRate(peer.downloadRate)).font(.system(size: 11))
            }
            .width(60)

            TableColumn("\u{2191}") { peer in
                Text(FormatHelpers.formatRate(peer.uploadRate)).font(.system(size: 11))
            }
            .width(60)

            TableColumn("Progress") { peer in
                Text(FormatHelpers.formatProgress(peer.progress)).font(.system(size: 11))
            }
            .width(60)
        }
        .task(id: viewModel.selectedTorrentID) {
            guard let id = viewModel.selectedTorrentID else { return }
            peers = await viewModel.peers(for: id)
        }
    }
}

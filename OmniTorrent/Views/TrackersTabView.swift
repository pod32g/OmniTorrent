import SwiftUI
import OmniTorrentEngine

struct TrackersTabView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var trackers: [TrackerInfo] = []

    var body: some View {
        Table(trackers) {
            TableColumn("URL") { tracker in
                Text(tracker.url).font(.system(size: 11, design: .monospaced))
            }
            .width(min: 200, ideal: 400)

            TableColumn("Tier") { tracker in
                Text("\(tracker.tier)").font(.system(size: 11))
            }
            .width(40)

            TableColumn("Peers") { tracker in
                Text("\(tracker.numPeers)").font(.system(size: 11))
            }
            .width(50)

            TableColumn("Status") { tracker in
                Text(tracker.isWorking ? "Working" : "Not connected")
                    .font(.system(size: 11))
                    .foregroundStyle(tracker.isWorking ? .green : .secondary)
            }
            .width(90)
        }
        .task(id: viewModel.selectedTorrentID) {
            guard let id = viewModel.selectedTorrentID else { return }
            trackers = await viewModel.trackers(for: id)
        }
    }
}

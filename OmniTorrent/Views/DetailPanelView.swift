import SwiftUI
import OmniTorrentEngine

enum DetailTab: String, CaseIterable {
    case files = "Files"
    case peers = "Peers"
    case trackers = "Trackers"
    case pieces = "Pieces"
    case info = "Info"
}

struct DetailPanelView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var selectedTab: DetailTab = .files

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            Group {
                switch selectedTab {
                case .files:
                    FilesTabView(viewModel: viewModel)
                case .peers:
                    PeersTabView(viewModel: viewModel)
                case .trackers:
                    TrackersTabView(viewModel: viewModel)
                case .pieces:
                    PieceMapView(viewModel: viewModel)
                case .info:
                    InfoTabView(viewModel: viewModel)
                }
            }
        }
        .glassPanel()
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}

extension View {
    @ViewBuilder
    func glassPanel() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

import SwiftUI
import OmniTorrentEngine

struct PieceMapView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var pieces: [Bool] = []

    var body: some View {
        ScrollView {
            if pieces.isEmpty {
                ContentUnavailableView(
                    "No Piece Data",
                    systemImage: "square.grid.3x3",
                    description: Text("Piece data will appear once metadata is loaded.")
                )
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(6), spacing: 1), count: 40), spacing: 1) {
                    ForEach(0..<pieces.count, id: \.self) { i in
                        Rectangle()
                            .fill(pieces[i] ? Color.blue : Color.gray.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(12)

                Text("\(pieces.filter { $0 }.count) / \(pieces.count) pieces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .task(id: viewModel.selectedTorrentID) {
            await loadPieces()
        }
    }

    private func loadPieces() async {
        guard let id = viewModel.selectedTorrentID else { return }
        pieces = await viewModel.pieces(for: id)
    }
}

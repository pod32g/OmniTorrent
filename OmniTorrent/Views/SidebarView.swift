import SwiftUI
import OmniTorrentEngine

struct SidebarView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        List(selection: $viewModel.sidebarFilter) {
            Section("Transfers") {
                ForEach(SidebarFilter.allCases, id: \.self) { filter in
                    Label(filter.rawValue, systemImage: filter.icon)
                        .tag(filter)
                }
            }
        }
        .background(.ultraThinMaterial)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Text("\u{2193} \(FormatHelpers.formatRate(viewModel.globalStats.downloadRate))")
                Text("\u{2191} \(FormatHelpers.formatRate(viewModel.globalStats.uploadRate))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
    }
}

extension SidebarFilter {
    var icon: String {
        switch self {
        case .all:       return "arrow.down.circle"
        case .seeding:   return "arrow.up.circle"
        case .paused:    return "pause.circle"
        case .completed: return "checkmark.circle"
        }
    }
}

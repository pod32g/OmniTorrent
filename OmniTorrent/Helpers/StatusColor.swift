import SwiftUI
import OmniTorrentEngine

extension TorrentState {
    var color: Color {
        switch self {
        case .downloading: return .blue
        case .seeding:     return .green
        case .paused:      return .secondary
        case .queued:      return .orange
        case .checking:    return .purple
        case .error:       return .red
        }
    }

    var label: String {
        switch self {
        case .downloading: return "Downloading"
        case .seeding:     return "Seeding"
        case .paused:      return "Paused"
        case .queued:      return "Queued"
        case .checking:    return "Checking"
        case .error:       return "Error"
        }
    }
}

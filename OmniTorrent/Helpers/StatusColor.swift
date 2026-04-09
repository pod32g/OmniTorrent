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

extension TorrentTag {
    var color: Color {
        switch self {
        case .none: return .clear
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }

    var label: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
}

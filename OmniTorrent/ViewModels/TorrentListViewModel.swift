import Foundation
import SwiftUI
import OmniTorrentEngine

enum SidebarFilter: String, CaseIterable {
    case all = "All Downloads"
    case seeding = "Seeding"
    case paused = "Paused"
    case completed = "Completed"
}

@MainActor
@Observable
final class TorrentListViewModel {
    let manager: TorrentManager
    private let persistence: Persistence

    var torrents: [Torrent] = []
    var globalStats: GlobalStats = .zero
    var selectedTorrentID: TorrentID?
    var sidebarFilter: SidebarFilter = .all
    var searchText: String = ""

    var filteredTorrents: [Torrent] {
        var result = torrents

        switch sidebarFilter {
        case .all: break
        case .seeding:
            result = result.filter { $0.state == .seeding }
        case .paused:
            result = result.filter { $0.state == .paused }
        case .completed:
            result = result.filter { $0.state == .seeding && $0.progress >= 1.0 }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var selectedTorrent: Torrent? {
        guard let id = selectedTorrentID else { return nil }
        return torrents.first { $0.id == id }
    }

    init() {
        self.persistence = Persistence.appSupport
        self.manager = TorrentManager(
            settings: persistence.loadSettingsOrDefaults(),
            persistence: persistence
        )
        Task { await start() }
    }

    private func start() async {
        await manager.start()

        for await event in await manager.events {
            handleEvent(event)
        }
    }

    private func handleEvent(_ event: TorrentEvent) {
        Task {
            let allTorrents = await manager.torrents
            self.torrents = Array(allTorrents.values).sorted { $0.name < $1.name }
            self.globalStats = await manager.globalStats
        }
    }

    // MARK: - Actions

    func addTorrent(source: TorrentSource) {
        Task {
            _ = try? await manager.addTorrent(source: source)
        }
    }

    func pauseTorrent(_ id: TorrentID) {
        Task { await manager.pauseTorrent(id) }
    }

    func resumeTorrent(_ id: TorrentID) {
        Task { await manager.resumeTorrent(id) }
    }

    func removeTorrent(_ id: TorrentID, deleteFiles: Bool = false) {
        Task { await manager.removeTorrent(id, deleteFiles: deleteFiles) }
    }

    func setSequentialDownload(_ id: TorrentID, enabled: Bool) {
        Task { await manager.setSequentialDownload(id, enabled: enabled) }
    }

    func setFilePriority(_ torrentID: TorrentID, fileIndex: Int, priority: FilePriority) {
        Task { await manager.setFilePriority(torrentID, fileIndex: fileIndex, priority: priority) }
    }

    func setTorrentDownloadLimit(_ id: TorrentID, bytesPerSec: Int) {
        Task { await manager.setTorrentDownloadLimit(id, bytesPerSec: bytesPerSec) }
    }

    func setTorrentUploadLimit(_ id: TorrentID, bytesPerSec: Int) {
        Task { await manager.setTorrentUploadLimit(id, bytesPerSec: bytesPerSec) }
    }

    func files(for id: TorrentID) async -> [FileEntry] {
        await manager.files(for: id)
    }

    func peers(for id: TorrentID) async -> [Peer] {
        await manager.peers(for: id)
    }

    func trackers(for id: TorrentID) async -> [TrackerInfo] {
        await manager.trackers(for: id)
    }
}

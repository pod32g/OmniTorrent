import Foundation
import SwiftUI
import UserNotifications
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
        switch event {
        case .completed(let torrent, let options):
            postCompletionNotification(for: torrent)
            executeCompletionAction(options.completionAction, torrent: torrent)
        default:
            break
        }

        Task {
            let allTorrents = await manager.torrents
            self.torrents = Array(allTorrents.values).sorted { $0.name < $1.name }
            self.globalStats = await manager.globalStats
        }
    }

    private func postCompletionNotification(for torrent: Torrent) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = torrent.name
        content.sound = .default
        content.categoryIdentifier = "TORRENT_COMPLETE"
        content.userInfo = ["savePath": torrent.savePath, "torrentName": torrent.name]
        let request = UNNotificationRequest(
            identifier: "complete-\(torrent.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func executeCompletionAction(_ action: CompletionAction, torrent: Torrent) {
        switch action {
        case .doNothing:
            break
        case .openFile:
            let url = URL(fileURLWithPath: torrent.savePath).appendingPathComponent(torrent.name)
            NSWorkspace.shared.open(url)
        case .revealInFinder:
            let path = URL(fileURLWithPath: torrent.savePath).appendingPathComponent(torrent.name).path
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: torrent.savePath)
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

    func torrentOptions(for id: TorrentID) async -> TorrentOptions {
        await manager.torrentOptions(for: id)
    }

    func setTorrentOptions(_ options: TorrentOptions, for id: TorrentID) {
        Task { await manager.setTorrentOptions(options, for: id) }
    }
}

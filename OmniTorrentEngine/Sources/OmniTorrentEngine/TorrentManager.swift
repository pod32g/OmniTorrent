import Foundation
import LibTorrentKit

public struct GlobalStats: Sendable {
    public var downloadRate: Int
    public var uploadRate: Int
    public var activeTorrents: Int

    public static let zero = GlobalStats(downloadRate: 0, uploadRate: 0, activeTorrents: 0)
}

public struct TrackerInfo: Identifiable, Sendable {
    public let id: String
    public let url: String
    public let tier: Int
    public let numPeers: Int
    public let isWorking: Bool
}

/// Central actor managing the libtorrent session and emitting torrent events.
public actor TorrentManager {
    private var session: OpaquePointer? // lt_session_t*
    private var settings: EngineSettings
    private let persistence: Persistence
    private var pollingTask: Task<Void, Never>?

    // Published state
    public private(set) var torrents: [TorrentID: Torrent] = [:]
    public private(set) var globalStats: GlobalStats = .zero

    // Maps engine torrent IDs to libtorrent handles
    private var handleMap: [TorrentID: OpaquePointer] = [:] // lt_torrent_t*

    // Event stream
    private let eventContinuation: AsyncStream<TorrentEvent>.Continuation
    public let events: AsyncStream<TorrentEvent>

    public init(settings: EngineSettings, persistence: Persistence) {
        self.settings = settings
        self.persistence = persistence

        let (stream, continuation) = AsyncStream<TorrentEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
    }

    // MARK: - Lifecycle

    public func start() {
        guard session == nil else { return }
        session = lt_session_create(Int32(settings.listenPort))

        if settings.maxDownloadRate > 0 {
            lt_session_set_download_limit(session, Int32(settings.maxDownloadRate))
        }
        if settings.maxUploadRate > 0 {
            lt_session_set_upload_limit(session, Int32(settings.maxUploadRate))
        }
        if settings.maxActiveDownloads > 0 {
            lt_session_set_active_downloads(session, Int32(settings.maxActiveDownloads))
        }
        if settings.maxActiveSeeds > 0 {
            lt_session_set_active_seeds(session, Int32(settings.maxActiveSeeds))
        }

        // Load resume data
        for (id, url) in persistence.allResumeDataFiles() {
            guard let data = try? Data(contentsOf: url) else { continue }
            data.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return }
                if let handle = lt_add_torrent_resume(
                    session, base, Int32(data.count),
                    nil // use save_path from resume data
                ) {
                    handleMap[id] = handle
                    torrents[id] = Torrent(id: id, name: "Loading...", state: .checking)
                }
            }
        }

        // Start polling
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self?.poll()
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil

        // Save resume data for all torrents
        for (id, handle) in handleMap {
            var len: Int32 = 0
            if let buf = lt_save_resume_data(handle, &len), len > 0 {
                let data = Data(bytes: buf, count: Int(len))
                free(buf)
                try? persistence.saveResumeData(data, for: id)
            }
        }

        if let session {
            lt_session_destroy(session)
        }
        session = nil
        handleMap.removeAll()
        eventContinuation.finish()
    }

    // MARK: - Adding Torrents

    public func addTorrent(source: TorrentSource, savePath: String? = nil) throws -> TorrentID {
        guard let session else { throw TorrentError.sessionError("Session not started") }
        let path = savePath ?? settings.downloadPath

        let handle: OpaquePointer?
        switch source {
        case .magnet(let uri):
            handle = lt_add_torrent_magnet(session, uri, path)
        case .file(let url):
            handle = lt_add_torrent_file(session, url.path, path)
        }

        guard let handle else {
            throw TorrentError.addFailed("Failed to add torrent")
        }

        let id = TorrentID()
        handleMap[id] = handle
        let torrent = Torrent(id: id, name: "Loading...", state: .checking)
        torrents[id] = torrent
        eventContinuation.yield(.added(torrent))
        return id
    }

    // MARK: - Torrent Control

    public func pauseTorrent(_ id: TorrentID) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_pause(handle)
    }

    public func resumeTorrent(_ id: TorrentID) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_resume(handle)
    }

    public func removeTorrent(_ id: TorrentID, deleteFiles: Bool = false) {
        guard let handle = handleMap[id], let session else { return }
        lt_torrent_remove(session, handle, deleteFiles)
        handleMap.removeValue(forKey: id)
        torrents.removeValue(forKey: id)
        try? persistence.deleteResumeData(for: id)
        eventContinuation.yield(.removed(id))
    }

    public func setSequentialDownload(_ id: TorrentID, enabled: Bool) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_set_sequential(handle, enabled)
    }

    public func setFilePriority(_ torrentID: TorrentID, fileIndex: Int, priority: FilePriority) {
        guard let handle = handleMap[torrentID] else { return }
        lt_set_file_priority(handle, Int32(fileIndex), Int32(priority.ltValue))
    }

    public func setTorrentDownloadLimit(_ id: TorrentID, bytesPerSec: Int) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_set_download_limit(handle, Int32(bytesPerSec))
    }

    public func setTorrentUploadLimit(_ id: TorrentID, bytesPerSec: Int) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_set_upload_limit(handle, Int32(bytesPerSec))
    }

    // MARK: - Settings

    public func updateSettings(_ newSettings: EngineSettings) {
        settings = newSettings
        if let session {
            lt_session_set_download_limit(session, Int32(newSettings.maxDownloadRate))
            lt_session_set_upload_limit(session, Int32(newSettings.maxUploadRate))
            lt_session_set_active_downloads(session, Int32(newSettings.maxActiveDownloads))
            lt_session_set_active_seeds(session, Int32(newSettings.maxActiveSeeds))
        }
        try? persistence.saveSettings(newSettings)
    }

    // MARK: - File & Peer Info

    public func files(for id: TorrentID) -> [FileEntry] {
        guard let handle = handleMap[id] else { return [] }
        let count = lt_get_file_count(handle)
        guard count > 0 else { return [] }

        var cFiles = [lt_file_info_t](repeating: lt_file_info_t(), count: Int(count))
        guard lt_get_files(handle, &cFiles, count) else { return [] }

        return (0..<Int(count)).map { i in
            FileEntry(
                id: i,
                path: String(cString: cFiles[i].path),
                size: cFiles[i].size,
                progress: cFiles[i].progress,
                priority: FilePriority.from(ltValue: Int(cFiles[i].priority))
            )
        }
    }

    public func peers(for id: TorrentID) -> [Peer] {
        guard let handle = handleMap[id] else { return [] }
        let count = lt_get_peer_count(handle)
        guard count > 0 else { return [] }

        let maxPeers = min(Int(count), 200)
        var cPeers = [lt_peer_info_t](repeating: lt_peer_info_t(), count: maxPeers)
        guard lt_get_peers(handle, &cPeers, Int32(maxPeers)) else { return [] }

        return (0..<maxPeers).map { i in
            Peer(
                ip: String(cString: cPeers[i].ip),
                port: Int(cPeers[i].port),
                client: String(cString: cPeers[i].client),
                downloadRate: Int(cPeers[i].download_rate),
                uploadRate: Int(cPeers[i].upload_rate),
                progress: cPeers[i].progress
            )
        }
    }

    public func trackers(for id: TorrentID) -> [TrackerInfo] {
        guard let handle = handleMap[id] else { return [] }
        let count = lt_get_tracker_count(handle)
        guard count > 0 else { return [] }
        var cTrackers = [lt_tracker_info_t](repeating: lt_tracker_info_t(), count: Int(count))
        guard lt_get_trackers(handle, &cTrackers, count) else { return [] }
        return (0..<Int(count)).map { i in
            TrackerInfo(
                id: String(cString: cTrackers[i].url),
                url: String(cString: cTrackers[i].url),
                tier: Int(cTrackers[i].tier),
                numPeers: Int(cTrackers[i].num_peers),
                isWorking: cTrackers[i].is_working
            )
        }
    }

    // MARK: - Polling

    private func poll() {
        guard session != nil else { return }

        var totalDown = 0
        var totalUp = 0
        var activeCount = 0

        for (id, handle) in handleMap {
            var status = lt_torrent_status_t()
            guard lt_get_status(handle, &status) else { continue }

            let newState = TorrentState.from(ltState: Int(status.state), isPaused: status.is_paused)
            let name = String(cString: status.name)
            let savePath = String(cString: status.save_path)
            let infoHash = String(cString: status.info_hash)

            let eta: Int
            if status.download_rate > 0 && status.total_size > status.total_done {
                eta = Int(status.total_size - status.total_done) / Int(status.download_rate)
            } else {
                eta = -1
            }

            let stats = TransferStats(
                downloadRate: Int(status.download_rate),
                uploadRate: Int(status.upload_rate),
                totalDownloaded: status.all_time_download,
                totalUploaded: status.all_time_upload,
                peersConnected: Int(status.num_peers),
                eta: eta
            )

            totalDown += Int(status.download_rate)
            totalUp += Int(status.upload_rate)
            if newState == .downloading || newState == .seeding { activeCount += 1 }

            // Diff and emit events
            if let existing = torrents[id] {
                if existing.state != newState {
                    eventContinuation.yield(.stateChanged(id: id, state: newState))
                }
                if existing.stats != stats {
                    eventContinuation.yield(.statsUpdated(id: id, stats: stats))
                }
            }

            // Update stored torrent
            torrents[id] = Torrent(
                id: id,
                name: name.isEmpty ? torrents[id]?.name ?? "Unknown" : name,
                state: newState,
                progress: status.progress,
                totalSize: status.total_size,
                savePath: savePath,
                files: torrents[id]?.files ?? [],
                stats: stats,
                infoHash: infoHash
            )
        }

        globalStats = GlobalStats(
            downloadRate: totalDown,
            uploadRate: totalUp,
            activeTorrents: activeCount
        )
    }
}

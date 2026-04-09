public enum TorrentEvent: Sendable {
    case added(Torrent)
    case stateChanged(id: TorrentID, state: TorrentState)
    case statsUpdated(id: TorrentID, stats: TransferStats)
    case fileProgress(id: TorrentID, files: [FileProgress])
    case peersUpdated(id: TorrentID, peers: [Peer])
    case removed(TorrentID)
    case completed(Torrent, TorrentOptions)
    case error(id: TorrentID, TorrentError)
}

public enum TorrentError: Error, Sendable {
    case invalidMagnetURI, fileNotFound, sessionError(String), addFailed(String)
}

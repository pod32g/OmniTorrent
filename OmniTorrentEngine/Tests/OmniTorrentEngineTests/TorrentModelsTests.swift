import Testing
@testable import OmniTorrentEngine

@Test func torrentStateFromLibtorrentRawValue() {
    #expect(TorrentState.from(ltState: 1, isPaused: false) == .checking)
    #expect(TorrentState.from(ltState: 3, isPaused: false) == .downloading)
    #expect(TorrentState.from(ltState: 5, isPaused: false) == .seeding)
    #expect(TorrentState.from(ltState: 3, isPaused: true) == .paused)
}

@Test func filePriorityRawValues() {
    #expect(FilePriority.skip.ltValue == 0)
    #expect(FilePriority.normal.ltValue == 4)
    #expect(FilePriority.high.ltValue == 7)
}

@Test func torrentSourceMagnet() {
    let source = TorrentSource.magnet("magnet:?xt=urn:btih:abc123")
    if case .magnet(let uri) = source {
        #expect(uri.contains("btih"))
    } else {
        Issue.record("Expected magnet source")
    }
}

@Test func transferStatsFormatsETA() {
    let stats = TransferStats(downloadRate: 1_000_000, uploadRate: 500_000, totalDownloaded: 500_000_000, totalUploaded: 250_000_000, peersConnected: 10, eta: 3661)
    #expect(stats.downloadRate == 1_000_000)
    #expect(stats.eta == 3661)
}

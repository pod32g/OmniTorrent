import Testing
@testable import LibTorrentKit

@Test func sessionCreateDestroy() {
    let session = lt_session_create(6881)
    #expect(session != nil)
    lt_session_destroy(session)
}

@Test func sessionTorrentCountStartsAtZero() {
    let session = lt_session_create(6882)!
    #expect(lt_session_torrent_count(session) == 0)
    lt_session_destroy(session)
}

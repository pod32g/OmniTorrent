import Testing
import Foundation
@testable import OmniTorrentEngine

@Test func managerStartsAndStops() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let manager = TorrentManager(settings: .defaults, persistence: persistence)
    await manager.start()
    let count = await manager.torrents.count
    #expect(count == 0)
    await manager.stop()
}

@Test func managerGlobalStats() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let manager = TorrentManager(settings: .defaults, persistence: persistence)
    await manager.start()
    let stats = await manager.globalStats
    #expect(stats.downloadRate == 0)
    #expect(stats.uploadRate == 0)
    await manager.stop()
}

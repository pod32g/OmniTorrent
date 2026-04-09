import Testing
import Foundation
@testable import OmniTorrentEngine

@Test func settingsRoundTrip() throws {
    let settings = EngineSettings(downloadPath: "/Users/test/Downloads", listenPort: 6881, maxDownloadRate: 1_000_000, maxUploadRate: 500_000, maxConnections: 200, launchAtLogin: false)
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(EngineSettings.self, from: data)
    #expect(decoded.downloadPath == settings.downloadPath)
    #expect(decoded.listenPort == settings.listenPort)
    #expect(decoded.maxDownloadRate == settings.maxDownloadRate)
}

@Test func settingsDefaults() {
    let settings = EngineSettings.defaults
    #expect(settings.listenPort == 6881)
    #expect(settings.maxDownloadRate == 0)
    #expect(settings.maxUploadRate == 0)
}

@Test func persistenceSaveAndLoadSettings() throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let settings = EngineSettings(downloadPath: "/tmp/test", listenPort: 7777, maxDownloadRate: 0, maxUploadRate: 0, maxConnections: 100)
    try persistence.saveSettings(settings)
    let loaded = try persistence.loadSettings()
    #expect(loaded.listenPort == 7777)
    #expect(loaded.downloadPath == "/tmp/test")
}

@Test func persistenceResumeData() throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let testData = Data([0x01, 0x02, 0x03, 0x04])
    let id = TorrentID()
    try persistence.saveResumeData(testData, for: id)
    let loaded = try persistence.loadResumeData(for: id)
    #expect(loaded == testData)
}

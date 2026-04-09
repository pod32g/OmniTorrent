import Testing
import Foundation
@testable import OmniTorrentEngine

@Test func optionsDefaultValues() {
    let options = TorrentOptions()
    #expect(options.completionAction == .doNothing)
    #expect(options.moveToPath == nil)
    #expect(options.hasCompleted == false)
}

@Test func optionsRoundTrip() throws {
    let options = TorrentOptions(completionAction: .openFile, moveToPath: "/Users/test/Media", hasCompleted: true)
    let data = try JSONEncoder().encode(options)
    let decoded = try JSONDecoder().decode(TorrentOptions.self, from: data)
    #expect(decoded.completionAction == .openFile)
    #expect(decoded.moveToPath == "/Users/test/Media")
    #expect(decoded.hasCompleted == true)
}

@Test func completionActionAllCases() {
    let cases = CompletionAction.allCases
    #expect(cases.count == 3)
}

@Test func persistenceOptionsRoundTrip() throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let persistence = Persistence(baseDirectory: tmpDir)
    let id = TorrentID()
    let options = TorrentOptions(completionAction: .revealInFinder, moveToPath: "/tmp/movies")
    try persistence.saveOptions(options, for: id)
    let loaded = persistence.loadOptions(for: id)
    #expect(loaded.completionAction == .revealInFinder)
    #expect(loaded.moveToPath == "/tmp/movies")
}

@Test func persistenceOptionsDefaultsWhenMissing() {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let persistence = Persistence(baseDirectory: tmpDir)
    let loaded = persistence.loadOptions(for: TorrentID())
    #expect(loaded.completionAction == .doNothing)
}

@Test func persistenceDeleteOptions() throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let persistence = Persistence(baseDirectory: tmpDir)
    let id = TorrentID()
    try persistence.saveOptions(TorrentOptions(completionAction: .openFile), for: id)
    try persistence.deleteOptions(for: id)
    let loaded = persistence.loadOptions(for: id)
    #expect(loaded.completionAction == .doNothing)
}

import Foundation
import OmniTorrentEngine

@MainActor
@Observable
final class SettingsViewModel {
    private let manager: TorrentManager

    var downloadPath: String
    var listenPort: Int
    var maxDownloadRate: Int
    var maxUploadRate: Int
    var maxConnections: Int
    var maxActiveDownloads: Int
    var maxActiveSeeds: Int
    var launchAtLogin: Bool

    init(manager: TorrentManager) {
        self.manager = manager
        let persistence = Persistence.appSupport
        let settings = persistence.loadSettingsOrDefaults()
        self.downloadPath = settings.downloadPath
        self.listenPort = settings.listenPort
        self.maxDownloadRate = settings.maxDownloadRate
        self.maxUploadRate = settings.maxUploadRate
        self.maxConnections = settings.maxConnections
        self.maxActiveDownloads = settings.maxActiveDownloads
        self.maxActiveSeeds = settings.maxActiveSeeds
        self.launchAtLogin = settings.launchAtLogin
    }

    func save() {
        let settings = EngineSettings(
            downloadPath: downloadPath,
            listenPort: listenPort,
            maxDownloadRate: maxDownloadRate,
            maxUploadRate: maxUploadRate,
            maxConnections: maxConnections,
            maxActiveDownloads: maxActiveDownloads,
            maxActiveSeeds: maxActiveSeeds,
            launchAtLogin: launchAtLogin
        )
        Task { await manager.updateSettings(settings) }
    }
}

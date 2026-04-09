import Foundation

public struct EngineSettings: Codable, Sendable, Equatable {
    public var downloadPath: String
    public var listenPort: Int
    public var maxDownloadRate: Int  // bytes/sec, 0 = unlimited
    public var maxUploadRate: Int    // bytes/sec, 0 = unlimited
    public var maxConnections: Int
    public var launchAtLogin: Bool

    public static let defaults = EngineSettings(
        downloadPath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first ?? "~/Downloads",
        listenPort: 6881,
        maxDownloadRate: 0,
        maxUploadRate: 0,
        maxConnections: 200,
        launchAtLogin: false
    )

    public init(downloadPath: String, listenPort: Int, maxDownloadRate: Int, maxUploadRate: Int, maxConnections: Int, launchAtLogin: Bool = false) {
        self.downloadPath = downloadPath
        self.listenPort = listenPort
        self.maxDownloadRate = maxDownloadRate
        self.maxUploadRate = maxUploadRate
        self.maxConnections = maxConnections
        self.launchAtLogin = launchAtLogin
    }
}

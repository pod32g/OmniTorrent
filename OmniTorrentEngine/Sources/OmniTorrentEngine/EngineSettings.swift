import Foundation

public struct ScheduleSlot: Codable, Sendable, Equatable {
    public var startHour: Int      // 0-23
    public var endHour: Int        // 0-23 (exclusive, wraps at midnight)
    public var maxDownloadRate: Int // bytes/sec, 0 = unlimited
    public var maxUploadRate: Int   // bytes/sec, 0 = unlimited

    public init(startHour: Int, endHour: Int, maxDownloadRate: Int, maxUploadRate: Int) {
        self.startHour = startHour
        self.endHour = endHour
        self.maxDownloadRate = maxDownloadRate
        self.maxUploadRate = maxUploadRate
    }
}

public struct EngineSettings: Codable, Sendable, Equatable {
    public var downloadPath: String
    public var listenPort: Int
    public var maxDownloadRate: Int  // bytes/sec, 0 = unlimited
    public var maxUploadRate: Int    // bytes/sec, 0 = unlimited
    public var maxConnections: Int
    public var maxActiveDownloads: Int  // 0 = unlimited
    public var maxActiveSeeds: Int      // 0 = unlimited
    public var launchAtLogin: Bool
    public var watchFolderPath: String?  // nil = disabled
    public var bandwidthSchedule: [ScheduleSlot]  // empty = no schedule (use global limits)
    public var webRemoteEnabled: Bool
    public var webRemotePort: Int  // default 8080

    public static let defaults = EngineSettings(
        downloadPath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first ?? "~/Downloads",
        listenPort: 6881,
        maxDownloadRate: 0,
        maxUploadRate: 0,
        maxConnections: 200,
        maxActiveDownloads: 3,
        maxActiveSeeds: 5,
        launchAtLogin: false,
        watchFolderPath: nil,
        bandwidthSchedule: [],
        webRemoteEnabled: false,
        webRemotePort: 8080
    )

    public init(downloadPath: String, listenPort: Int, maxDownloadRate: Int, maxUploadRate: Int, maxConnections: Int, maxActiveDownloads: Int = 3, maxActiveSeeds: Int = 5, launchAtLogin: Bool = false, watchFolderPath: String? = nil, bandwidthSchedule: [ScheduleSlot] = [], webRemoteEnabled: Bool = false, webRemotePort: Int = 8080) {
        self.downloadPath = downloadPath
        self.listenPort = listenPort
        self.maxDownloadRate = maxDownloadRate
        self.maxUploadRate = maxUploadRate
        self.maxConnections = maxConnections
        self.maxActiveDownloads = maxActiveDownloads
        self.maxActiveSeeds = maxActiveSeeds
        self.launchAtLogin = launchAtLogin
        self.watchFolderPath = watchFolderPath
        self.bandwidthSchedule = bandwidthSchedule
        self.webRemoteEnabled = webRemoteEnabled
        self.webRemotePort = webRemotePort
    }
}

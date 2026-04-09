public struct TransferStats: Sendable, Equatable {
    public var downloadRate: Int
    public var uploadRate: Int
    public var totalDownloaded: Int64
    public var totalUploaded: Int64
    public var peersConnected: Int
    public var eta: Int

    public static let zero = TransferStats(downloadRate: 0, uploadRate: 0, totalDownloaded: 0, totalUploaded: 0, peersConnected: 0, eta: -1)

    public init(downloadRate: Int, uploadRate: Int, totalDownloaded: Int64, totalUploaded: Int64, peersConnected: Int, eta: Int) {
        self.downloadRate = downloadRate; self.uploadRate = uploadRate
        self.totalDownloaded = totalDownloaded; self.totalUploaded = totalUploaded
        self.peersConnected = peersConnected; self.eta = eta
    }
}

public struct FileProgress: Sendable {
    public let index: Int
    public let progress: Float
    public init(index: Int, progress: Float) { self.index = index; self.progress = progress }
}

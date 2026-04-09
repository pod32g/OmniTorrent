public struct Peer: Sendable, Identifiable {
    public var id: String { "\(ip):\(port)" }
    public var ip: String
    public var port: Int
    public var client: String
    public var downloadRate: Int
    public var uploadRate: Int
    public var progress: Float

    public init(ip: String, port: Int, client: String, downloadRate: Int, uploadRate: Int, progress: Float) {
        self.ip = ip; self.port = port; self.client = client
        self.downloadRate = downloadRate; self.uploadRate = uploadRate; self.progress = progress
    }
}

import Foundation

public class WatchFolderMonitor: @unchecked Sendable {
    private let path: String
    private let onTorrentFound: @Sendable (URL) async -> Bool
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.omnitorrent.watchfolder")

    public init(path: String, onTorrentFound: @escaping @Sendable (URL) async -> Bool) {
        self.path = path
        self.onTorrentFound = onTorrentFound
    }

    public func start() {
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.scanDirectory()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source?.resume()

        // Initial scan for any files already present
        queue.async { [weak self] in
            self?.scanDirectory()
        }
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    private func scanDirectory() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: nil
        ) else { return }

        let torrentFiles = contents.filter { $0.pathExtension == "torrent" }

        for file in torrentFiles {
            let callback = onTorrentFound
            Task {
                let success = await callback(file)
                if success {
                    try? FileManager.default.trashItem(at: file, resultingItemURL: nil)
                }
            }
        }
    }
}

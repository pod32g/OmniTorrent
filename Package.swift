// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniTorrent",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "OmniTorrentEngine"),
    ],
    targets: [
        .executableTarget(
            name: "OmniTorrent",
            dependencies: ["OmniTorrentEngine"],
            path: "OmniTorrent"
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniTorrentEngine",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OmniTorrentEngine", targets: ["OmniTorrentEngine"]),
    ],
    dependencies: [
        .package(path: "../LibTorrentKit"),
    ],
    targets: [
        .target(
            name: "OmniTorrentEngine",
            dependencies: ["LibTorrentKit"],
            path: "Sources/OmniTorrentEngine"
        ),
        .testTarget(
            name: "OmniTorrentEngineTests",
            dependencies: ["OmniTorrentEngine"]
        ),
    ]
)

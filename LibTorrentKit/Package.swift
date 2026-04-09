// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LibTorrentKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LibTorrentKit", targets: ["LibTorrentKit"]),
    ],
    targets: [
        .target(
            name: "LibTorrentKit",
            path: "Sources/LibTorrentKit",
            sources: ["libtorrentkit.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../lib/include"),
                .unsafeFlags(["-I/opt/homebrew/include"]),
                .define("TORRENT_USE_OPENSSL", to: "1"),
                .define("BOOST_ASIO_HAS_STD_INVOKE_RESULT", to: "1"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L/Users/pod32g/Documents/code/OmniTorrent/LibTorrentKit/lib/lib",
                    "-L/opt/homebrew/lib",
                ]),
                .linkedLibrary("torrent-rasterbar"),
                .linkedLibrary("ssl"),
                .linkedLibrary("crypto"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .testTarget(
            name: "LibTorrentKitTests",
            dependencies: ["LibTorrentKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)

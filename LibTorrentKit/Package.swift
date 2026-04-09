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
                .define("TORRENT_USE_OPENSSL", to: "1"),
                .define("BOOST_ASIO_HAS_STD_INVOKE_RESULT", to: "1"),
            ]
            // NOTE: linkerSettings referencing libtorrent-rasterbar, ssl, crypto,
            // and -L../../lib/lib will be added back in Task 3 once libtorrent is built.
        ),
        .testTarget(
            name: "LibTorrentKitTests",
            dependencies: ["LibTorrentKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)

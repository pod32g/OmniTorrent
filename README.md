# OmniTorrent

A lightweight, native macOS torrent client built with Swift and SwiftUI.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Native macOS app with Liquid Glass UI
- Magnet link and `.torrent` file support
- Per-file selection with priority (Skip / Normal / High)
- Sequential download mode
- Per-torrent and global bandwidth limits
- Active download/seed queue limits
- Detail panel with Files, Peers, Trackers, and Info tabs
- Resume data persistence across app restarts
- Keyboard shortcuts (Space = pause/resume, Delete = remove, Cmd+O = open)
- Drag & drop `.torrent` files onto the window

## Architecture

Three-layer Swift Package stack:

```
OmniTorrent (SwiftUI App)
    └── OmniTorrentEngine (Swift async API, TorrentManager actor)
            └── LibTorrentKit (C bridge over libtorrent-rasterbar 2.x)
```

## Building

### Prerequisites

- macOS 26+
- Xcode 26+
- Homebrew (`brew install cmake boost openssl@3`)

### Steps

```bash
# 1. Build libtorrent from source (~5-10 minutes)
cd LibTorrentKit
./build-libtorrent.sh

# 2. Open and run in Xcode
cd ..
open OmniTorrent.xcodeproj
# Cmd+R to build and run
```

## Usage

- **Add torrents**: Click `+`, drag & drop `.torrent` files, or open magnet links
- **Manage**: Right-click any torrent for pause/resume, bandwidth limits, sequential mode
- **File selection**: Click a torrent, then use the Files tab to set per-file priority
- **Settings**: `Cmd+,` for download path, speed limits, queue limits, and connection settings

## License

MIT

# OmniTorrent — Design Spec

A lightweight, native macOS torrent client built with Swift and SwiftUI, targeting macOS 26 with full liquid glass UI. Personal use only — no App Store distribution, no sandboxing.

## Goals

- Clean, focused torrent client that does the core job beautifully
- Fully native macOS experience with liquid glass design language
- Support both magnet links and .torrent files
- Download + seed workflow with per-file selection, sequential download, and bandwidth limits

## Non-Goals

- Built-in search/discovery (user finds torrents externally)
- RSS feeds, scheduling, IP filtering, or other power-user features
- App Store distribution, notarization, or sandboxing
- Cross-platform support

## Architecture

Three-layer Swift Package structure with clear dependency direction:

```
┌─────────────────────────────┐
│     OmniTorrent (App)       │  SwiftUI, macOS 26
│     Views, ViewModels       │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   OmniTorrentEngine         │  Pure Swift, async/await
│   TorrentManager (actor)    │  Swift Package
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   LibTorrentKit             │  C++ interop layer
│   C header bridging         │  Swift Package (C/C++)
└─────────────────────────────┘
```

### LibTorrentKit

Thin C wrapper around libtorrent (rasterbar). Exposes C functions that Swift can call directly via the C interop bridge. This is the only place C++ code exists in the project.

Key functions:
- `lt_session_create()` / `lt_session_destroy()`
- `lt_add_torrent_magnet()` / `lt_add_torrent_file()`
- `lt_get_torrent_status()` / `lt_get_file_progress()`
- `lt_set_file_priority()` / `lt_set_sequential_download()`
- `lt_set_download_limit()` / `lt_set_upload_limit()`
- `lt_pause()` / `lt_resume()` / `lt_remove()`
- `lt_get_peers()` / `lt_save_resume_data()`

### OmniTorrentEngine

Pure Swift package providing an async API over LibTorrentKit. The central type is `TorrentManager`, an actor that owns the libtorrent session.

**Event stream:**

```swift
enum TorrentEvent {
    case added(Torrent)
    case stateChanged(id: TorrentID, state: TorrentState)
    case statsUpdated(id: TorrentID, stats: TransferStats)
    case fileProgress(id: TorrentID, files: [FileProgress])
    case peersUpdated(id: TorrentID, peers: [Peer])
    case removed(TorrentID)
    case error(id: TorrentID, Error)
}
```

The manager exposes `var events: AsyncStream<TorrentEvent>` for the UI layer to observe.

**Polling:** libtorrent doesn't push state — the engine runs a 1-second timer, polls status via LibTorrentKit, diffs against previous state, and emits only changed events.

**Domain types:**

| Type | Fields |
|------|--------|
| `Torrent` | id, name, state, progress, totalSize, savePath, files |
| `TorrentState` | `.downloading`, `.seeding`, `.paused`, `.checking`, `.queued`, `.error` |
| `TransferStats` | downloadRate, uploadRate, totalDownloaded, totalUploaded, peersConnected, eta |
| `FileEntry` | path, size, progress, priority (skip/normal/high) |
| `Peer` | ip, port, client, downloadRate, uploadRate, progress, flags |

### OmniTorrent (App)

SwiftUI application targeting macOS 26. ViewModels use `@Observable` and consume the engine's `AsyncStream`.

**Entry points for adding torrents:**
- Magnet link URL scheme handler (`magnet:` URI)
- `.torrent` file association (open with)
- Drag & drop onto window or Dock icon
- "+" button / File > Open menu

## Data Flow

```
User action (drop file, click magnet, press +)
  → ViewModel calls engine.addTorrent(source:)
  → Engine validates, calls LibTorrentKit
  → LibTorrentKit adds to libtorrent session
  → Engine polls (1s interval), diffs state
  → Engine emits TorrentEvent into AsyncStream
  → ViewModel receives event, @Observable updates
  → SwiftUI re-renders affected views
```

## Persistence

All data stored in `~/Library/Application Support/OmniTorrent/`:

- `resume/` — libtorrent fastresume blobs per torrent (saved on pause/quit, loaded on launch)
- `settings.json` — user preferences (download path, bandwidth limits, default save location)

No database. Resume data is binary blobs from libtorrent. Settings is a simple Codable struct.

## UI Design

### Layout

`NavigationSplitView` with:
- **Sidebar** (230pt): Filter categories + global speed stats
- **Content**: Torrent list (top) + detail panel (bottom, when selected)

### Liquid Glass

Fully native macOS 26 liquid glass. No opaque backgrounds. Wallpaper bleeds through all surfaces.

**Glass hierarchy (3 levels):**

1. **Sidebar** — `.glassEffect(.regular)` — translucent panel with frosted blur
2. **Torrent cards** — `.glassEffect(.thin)` — lighter glass floating in the content area
3. **Detail panel** — `.glassEffect(.regular)` — secondary glass surface for file/peer/tracker info

**Window configuration:**
- `.preferredGlassBackgroundEffect()` on the window
- System materials adapt automatically to wallpaper colors

### Sidebar

Filter categories with count badges:
- All Downloads
- Seeding
- Paused
- Completed

Bottom: global transfer speed stats (↓ / ↑) in a glass chip.

### Torrent Cards

Each card shows:
- **Title**: torrent name (truncated with ellipsis)
- **Status badge**: pill with state-specific color
  - Downloading → system blue
  - Seeding → system green
  - Paused → system secondary/gray
  - Error → system red
- **Metadata line**: size, speed, ETA/ratio, peer count
- **Progress bar**: thin, rounded, color matches status

Selected card gets a subtle border highlight and elevated glass.

### Detail Panel

Appears below the torrent list when a torrent is selected. Uses a native segmented picker for tabs:

- **Files**: per-file checkboxes (native toggle), file size, priority selector (Skip/Normal/High)
- **Peers**: connected peers with client name, speed (↓/↑), progress percentage
- **Trackers**: tracker URLs with status and peer count
- **Info**: torrent hash, creation date, comment, total size, save path, piece count/size

### Native Controls

All controls are standard SwiftUI/AppKit:
- `NSSearchField` for search
- Segmented picker for detail tabs
- Native checkboxes for file selection
- System accent color throughout
- Standard traffic light window buttons
- Right-click context menus on torrent rows (Pause/Resume/Remove/Reveal in Finder)
- Menu bar: File > Open Torrent, Edit > Select All, etc.

### Interactions

- **Drag & drop**: .torrent files onto window or Dock icon
- **Magnet links**: registered URL scheme handler
- **Keyboard**: Delete to remove, Space to pause/resume, Cmd+O to open
- **Context menu**: right-click any torrent row

## Key Features

### Sequential Download
Toggle per-torrent via context menu or detail panel. Calls `lt_set_sequential_download()` on the libtorrent handle.

### Bandwidth Limits
Global limits configurable in Settings (Cmd+,). Per-torrent overrides available via context menu. Stored in settings.json.

### File Selection
Per-file priority in the Files tab of the detail panel:
- **High**: download first
- **Normal**: download normally
- **Skip**: don't download this file

Changes call `lt_set_file_priority()` immediately.

## Settings Window

Minimal preferences (Cmd+,):
- **General**: Default save location, start on login
- **Transfers**: Global download/upload speed limits
- **Connection**: Listening port, max connections

## Technical Notes

- **Minimum target**: macOS 26
- **Swift version**: 6.x with strict concurrency
- **Build system**: Swift Package Manager for LibTorrentKit and Engine; Xcode project for the app target
- **libtorrent version**: Latest stable (2.x branch), compiled via CMake and linked as a static library
- **No third-party Swift dependencies** — just libtorrent and Apple frameworks

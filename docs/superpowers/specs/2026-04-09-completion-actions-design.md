# Completion Actions — Design Spec

Per-torrent actions that fire when a download finishes: system notifications, move to folder, and open/reveal the file.

## Features

### 1. System Notifications

When any torrent completes, post a macOS notification via `UNUserNotificationCenter`:
- **Title:** "Download Complete"
- **Body:** Torrent name
- **Action button:** "Show in Finder" — reveals the downloaded file/folder
- **userInfo:** `["savePath": torrent.savePath, "torrentName": torrent.name]` — so the delegate can reveal the file without querying live engine state

Permission is requested on first app launch. If denied, notifications are silently skipped.

### 2. Move on Complete

Per-torrent optional move path. When a torrent finishes and `moveToPath` is set, the engine calls `lt_torrent_move_storage()` (new C bridge function) to tell libtorrent to relocate the files. This ensures libtorrent's internal save path stays in sync — subsequent polls will return the new path from `lt_get_status`.

- Default: don't move (nil)
- Set via context menu ("Move To..." opens folder picker) or Info tab in detail panel
- The move happens in the engine layer before the `.completed` event is emitted, so the ViewModel always sees the final path

### 3. Open / Reveal When Done

Per-torrent completion action with three options:
- **Do Nothing** (default)
- **Open File** — opens the file with the default app (`NSWorkspace.shared.open`)
- **Reveal in Finder** — selects the file in Finder (`NSWorkspace.shared.selectFile`)

For multi-file torrents, "Open File" opens the containing folder. "Reveal in Finder" reveals the folder.

## New Types

### OmniTorrentEngine

```swift
enum CompletionAction: String, Codable, Sendable, CaseIterable {
    case doNothing
    case openFile
    case revealInFinder
}

struct TorrentOptions: Codable, Sendable {
    var completionAction: CompletionAction = .doNothing
    var moveToPath: String? = nil
    var hasCompleted: Bool = false  // persisted flag to prevent re-firing after restart
}
```

### New Event

```swift
case completed(Torrent, TorrentOptions)  // includes options so ViewModel can act without a round-trip
```

## Architecture

### Engine Layer

**New C bridge function:**
```c
void lt_torrent_move_storage(lt_torrent_t* torrent, const char* new_path);
```
Wraps `torrent_handle::move_storage()` which tells libtorrent to move files and update its internal save path.

**Polling loop change:** The poll method already diffs `TorrentState` for each torrent. When a torrent transitions to `.seeding` or `.finished`:

1. Check `options.hasCompleted` — if true, skip (already fired)
2. If `moveToPath` is set, call `lt_torrent_move_storage()` to relocate files via libtorrent
3. Set `options.hasCompleted = true` and persist
4. Emit `.completed(torrent, options)` event

On startup, torrents loaded from resume data that are already in `.seeding`/`.finished` state will have `hasCompleted = true` in their persisted options, so no spurious completion events fire.

**Persistence:** `TorrentOptions` is stored per-torrent in a separate directory: `options/<uuid>.json` (not in `resume/` to avoid conflicts with `allResumeDataFiles()`). Loaded on startup, saved when modified.

**New Persistence methods:**
- `saveOptions(_:for:)` — saves TorrentOptions JSON to `options/<uuid>.json`
- `loadOptions(for:) -> TorrentOptions` — loads or returns defaults
- `deleteOptions(for:)` — called when torrent is removed

**TorrentManager stores options in memory:** `private var optionsMap: [TorrentID: TorrentOptions]` — loaded at startup, updated via `setTorrentOptions`, persisted on change.

**New TorrentManager methods:**
- `setTorrentOptions(_:for:)` — updates options and persists
- `torrentOptions(for:) -> TorrentOptions` — reads from in-memory map

### App Layer

**ViewModel:** Handles `.completed` events directly — the event includes `TorrentOptions` so no async round-trip needed:
1. Post `UNNotificationRequest` with `userInfo` containing `savePath` and `torrentName`
2. Execute `completionAction` from the included options (open file or reveal in Finder)
3. No move logic — engine already handled it via libtorrent

**Notification setup:** Request `UNUserNotificationCenter` authorization in `AppDelegate.applicationDidFinishLaunching`. Define a notification category "TORRENT_COMPLETE" with action "SHOW_IN_FINDER".

**Notification delegate:** `AppDelegate` conforms to `UNUserNotificationCenterDelegate`. On "SHOW_IN_FINDER" action, reads `savePath` from `notification.request.content.userInfo` and calls `NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: savePath)`.

### UI Changes

**Context menu** (TorrentCardView) — add submenu after the existing bandwidth limits:
```
On Complete ▸
  ✓ Do Nothing
    Open File
    Reveal in Finder
  ─────────────
    Move To...       (opens NSOpenPanel folder picker)
    Don't Move       (clears moveToPath)
```

**Info tab** (InfoTabView) — add section at the bottom:
- "On Complete" picker: Do Nothing / Open File / Reveal in Finder
- "Move To" row: path text + "Choose..." button / "None" with clear button

## Files Changed

### LibTorrentKit
- Modify: `LibTorrentKit/Sources/LibTorrentKit/include/libtorrentkit.h` — add `lt_torrent_move_storage`
- Modify: `LibTorrentKit/Sources/LibTorrentKit/libtorrentkit.cpp` — implement `lt_torrent_move_storage`

### Engine
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Models/TorrentOptions.swift`
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentEvent.swift` — add `.completed` case
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentManager.swift` — completion detection, move via libtorrent, options storage
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/Persistence.swift` — options save/load/delete in `options/` subdirectory

### App
- Modify: `OmniTorrent/OmniTorrentApp.swift` — notification permission, delegate, category registration
- Modify: `OmniTorrent/ViewModels/TorrentListViewModel.swift` — handle `.completed`, post notifications, execute actions
- Modify: `OmniTorrent/Views/TorrentCardView.swift` — "On Complete" context submenu
- Modify: `OmniTorrent/Views/InfoTabView.swift` — completion options section

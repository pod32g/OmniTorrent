# Completion Actions — Design Spec

Per-torrent actions that fire when a download finishes: system notifications, move to folder, and open/reveal the file.

## Features

### 1. System Notifications

When any torrent completes, post a macOS notification via `UNUserNotificationCenter`:
- **Title:** "Download Complete"
- **Body:** Torrent name
- **Action button:** "Show in Finder" — reveals the downloaded file/folder

Permission is requested on first app launch. If denied, notifications are silently skipped.

### 2. Move on Complete

Per-torrent optional move path. When a torrent finishes and `moveToPath` is set, the engine moves the downloaded files to the target directory and updates the torrent's `savePath`.

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
}
```

### New Event

```swift
case completed(Torrent)  // added to TorrentEvent enum
```

## Architecture

### Engine Layer

**Polling loop change:** The poll method already diffs `TorrentState` for each torrent. Add a `completedTorrents: Set<TorrentID>` to track which torrents have already fired completion. When a torrent transitions to `.seeding` or `.finished` and is not in the set:

1. If `moveToPath` is set, move downloaded files to the target directory using `FileManager`
2. Update the torrent's `savePath` to the new location
3. Add to `completedTorrents` set
4. Emit `.completed(torrent)` event

**Persistence:** `TorrentOptions` is stored per-torrent as `resume/<uuid>.options.json` alongside the existing resume data blob. Loaded on startup, saved when modified.

**New Persistence methods:**
- `saveOptions(_:for:)` — saves TorrentOptions JSON
- `loadOptions(for:) -> TorrentOptions` — loads or returns defaults
- `deleteOptions(for:)` — called when torrent is removed

**New TorrentManager methods:**
- `setTorrentOptions(_:for:)` — updates options and persists
- `torrentOptions(for:) -> TorrentOptions` — reads current options

### App Layer

**ViewModel:** Handles `.completed` events:
1. Post `UNNotificationRequest`
2. Execute `completionAction` (open file or reveal in Finder)
3. No move logic — engine already handled it

**Notification setup:** Request `UNUserNotificationCenter` authorization in `OmniTorrentApp.init` or `AppDelegate.applicationDidFinishLaunching`. Define a notification category with "Show in Finder" action.

**Notification delegate:** Implement `UNUserNotificationCenterDelegate` in AppDelegate to handle the "Show in Finder" action tap.

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

### Engine
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Models/TorrentOptions.swift`
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentEvent.swift` — add `.completed` case
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentManager.swift` — completion detection, move logic, options storage
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/Persistence.swift` — options save/load/delete

### App
- Modify: `OmniTorrent/OmniTorrentApp.swift` — notification permission request
- Modify: `OmniTorrent/ViewModels/TorrentListViewModel.swift` — handle `.completed`, post notifications, execute actions
- Modify: `OmniTorrent/Views/TorrentCardView.swift` — "On Complete" context submenu
- Modify: `OmniTorrent/Views/InfoTabView.swift` — completion options section

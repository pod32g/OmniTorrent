# Watch Folder & Menu Bar Item — Design Spec

Two background automation features: auto-import torrents from a watched directory, and a menu bar item for at-a-glance status.

## Feature 1: Watch Folder

### Behavior

Monitor a configurable directory for new `.torrent` files. When one appears, add it to the engine. Only delete the source file after a successful add.

- **Path:** Stored in `EngineSettings.watchFolderPath: String?` — nil means disabled
- **Monitoring:** `DispatchSource.makeFileSystemObjectSource` with `eventMask: .write` on the directory's file descriptor (vnode source). The `.write` event fires when the directory's contents change (file added/removed). On each event, scan the directory for `*.torrent` files.
- **On detection:** For each `.torrent` file found, attempt `manager.addTorrent(source: .file(url))`. Only if the add succeeds, move the source file to Trash via `FileManager.trashItem`. If the add fails (corrupt, duplicate), leave the file in place and log the error.
- **Actor hop:** The `onTorrentFound` callback runs on the monitor's private dispatch queue. It must use `Task { await manager.addTorrent(...) }` to hop to the actor's isolation context.
- **Lifecycle:** TorrentManager owns the monitor. Started in `start()` if path is set, restarted on `updateSettings()` if path changes, stopped in `stop()`

### New Types

```swift
// In OmniTorrentEngine
class WatchFolderMonitor: @unchecked Sendable {
    private let path: String
    private let onTorrentFound: @Sendable (URL) async -> Bool  // returns true if add succeeded
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.omnitorrent.watchfolder")

    init(path: String, onTorrentFound: @escaping @Sendable (URL) async -> Bool)
    func start()   // opens FD, creates DispatchSource, does initial scan
    func stop()    // cancels source, closes FD
}
```

The monitor opens the directory FD with `open(path, O_EVTONLY)`, creates the vnode dispatch source, and on each event scans for `.torrent` files. Initial scan on `start()` catches any files already present.

### Settings Change

Add to `EngineSettings`:
```swift
public var watchFolderPath: String?  // nil = disabled
```

Default: nil (disabled). Update `EngineSettings.defaults`, `init`, and all call sites (`SettingsViewModel.save()`).

Note: This app is personal-use only, not sandboxed, so no security-scoped bookmarks needed. Plain path strings work fine with full disk access.

### UI

Settings > General tab — new row after "Launch at Login":
- "Watch Folder" label
- Path text (or "Disabled") + "Choose..." button + "Disable" button (if enabled)

## Feature 2: Menu Bar Item

### Menu Bar Text

Live speed display in the menu bar: `↓ 2.1 MB/s  ↑ 840 KB/s`

Updates every polling cycle (1 second) via the shared ViewModel's `globalStats`.

When no transfers are active, shows: `↓ 0 B/s  ↑ 0 B/s`

### Dropdown View

Click the menu bar text to open a dropdown:

```
↓ 2.1 MB/s   ↑ 840 KB/s
─────────────────────────
ubuntu-26.04...    67%  Downloading
Fedora-Works...   100%  Seeding
Blender-4.3...     23%  Paused
─────────────────────────
Show OmniTorrent
Quit
```

- **Speed summary** at top
- **Active torrents** — up to 5 rows, each showing truncated name, progress %, state label. If more than 5, show "and N more..."
- **"Show OmniTorrent"** — calls `NSApp.activate()` and opens/brings forward the main window
- **"Quit"** — calls `NSApp.terminate(nil)`

### Background Running

- `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false` — app stays alive via menu bar
- `AppDelegate.applicationShouldHandleReopen(_:hasVisibleWindows:)` — if no visible windows, re-opens the main window. Returns `true`.
- Cmd+Q or "Quit" button terminates the app (triggers normal shutdown with resume data save)

### Implementation

**SwiftUI `MenuBarExtra` scene** in OmniTorrentApp (requires macOS 13+, which is well below our macOS 26 target):
```swift
MenuBarExtra {
    MenuBarDropdownView(viewModel: viewModel)
} label: {
    Text("↓ \(FormatHelpers.formatRate(viewModel.globalStats.downloadRate))  ↑ \(FormatHelpers.formatRate(viewModel.globalStats.uploadRate))")
}
```

**Data flow:** Shares the same `TorrentListViewModel` as the main window. No separate state needed.

### New View

`MenuBarDropdownView.swift` — the dropdown content. A simple VStack with speed stats, torrent rows, and action buttons.

## Files Changed

### Engine
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/WatchFolderMonitor.swift`
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/EngineSettings.swift` — add `watchFolderPath`, update `defaults` and `init`
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentManager.swift` — own and manage WatchFolderMonitor

### App
- Create: `OmniTorrent/Views/MenuBarDropdownView.swift`
- Modify: `OmniTorrent/OmniTorrentApp.swift` — add MenuBarExtra scene
- Modify: `OmniTorrent/OmniTorrentApp.swift` — add `applicationShouldTerminateAfterLastWindowClosed` and `applicationShouldHandleReopen` to AppDelegate
- Modify: `OmniTorrent/Views/SettingsView.swift` — watch folder config in General tab
- Modify: `OmniTorrent/ViewModels/SettingsViewModel.swift` — add watchFolderPath, update save()

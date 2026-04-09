# Watch Folder & Menu Bar Item — Design Spec

Two background automation features: auto-import torrents from a watched directory, and a menu bar item for at-a-glance status.

## Feature 1: Watch Folder

### Behavior

Monitor a configurable directory for new `.torrent` files. When one appears, add it to the engine and delete the source file.

- **Path:** Stored in `EngineSettings.watchFolderPath: String?` — nil means disabled
- **Monitoring:** `DispatchSource.makeFileSystemObjectSource` with `.write` flag on the directory's file descriptor
- **On detection:** Scan directory for `*.torrent` files, call `manager.addTorrent(source: .file(url))` for each, then `FileManager.removeItem` to delete the source file
- **Lifecycle:** TorrentManager owns the monitor. Started in `start()` if path is set, restarted on `updateSettings()` if path changes, stopped in `stop()`

### New Types

```swift
// In OmniTorrentEngine
class WatchFolderMonitor: @unchecked Sendable {
    private let path: String
    private let onTorrentFound: @Sendable (URL) -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.omnitorrent.watchfolder")

    init(path: String, onTorrentFound: @escaping @Sendable (URL) -> Void)
    func start()
    func stop()
}
```

### Settings Change

Add to `EngineSettings`:
```swift
public var watchFolderPath: String?  // nil = disabled
```

Default: nil (disabled).

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

- `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false`
- App stays alive via menu bar when all windows are closed
- Cmd+Q or "Quit" button terminates the app (triggers normal shutdown with resume data save)
- Clicking the Dock icon re-shows the main window

### Implementation

**SwiftUI `MenuBarExtra` scene** in OmniTorrentApp:
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
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/EngineSettings.swift` — add `watchFolderPath`
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentManager.swift` — own and manage WatchFolderMonitor

### App
- Create: `OmniTorrent/Views/MenuBarDropdownView.swift`
- Modify: `OmniTorrent/OmniTorrentApp.swift` — add MenuBarExtra scene, applicationShouldTerminateAfterLastWindowClosed
- Modify: `OmniTorrent/Views/SettingsView.swift` — watch folder config in General tab
- Modify: `OmniTorrent/ViewModels/SettingsViewModel.swift` — add watchFolderPath

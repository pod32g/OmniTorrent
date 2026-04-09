# OmniTorrent Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS torrent client wrapping libtorrent (rasterbar) with a liquid glass SwiftUI interface.

**Architecture:** Three-layer Swift Package stack — LibTorrentKit (C++ bridge) → OmniTorrentEngine (Swift async API) → OmniTorrent app (SwiftUI). Each layer is a separate Swift package with a clear dependency boundary.

**Tech Stack:** Swift 6, SwiftUI (macOS 26), libtorrent 2.x (C++ via CMake), Swift Package Manager, Xcode

**Spec:** `docs/superpowers/specs/2026-04-09-omnitorrent-design.md`

---

## File Structure

```
OmniTorrent/
├── Package.swift                          # Root workspace (if using SPM workspace) or just Xcode project
├── OmniTorrent.xcodeproj/                 # Xcode project for app target
│
├── LibTorrentKit/
│   ├── Package.swift                      # Swift package manifest (C/C++ target)
│   ├── build-libtorrent.sh               # Script to compile libtorrent via CMake
│   ├── Sources/
│   │   └── LibTorrentKit/
│   │       ├── include/
│   │       │   └── libtorrentkit.h        # Public C header — all lt_* functions
│   │       └── libtorrentkit.cpp          # C++ implementation wrapping libtorrent API
│   └── Tests/
│       └── LibTorrentKitTests/
│           └── LibTorrentKitTests.swift   # Basic smoke tests (session create/destroy)
│
├── OmniTorrentEngine/
│   ├── Package.swift                      # Swift package manifest (depends on LibTorrentKit)
│   ├── Sources/
│   │   └── OmniTorrentEngine/
│   │       ├── Models/
│   │       │   ├── Torrent.swift          # Torrent, TorrentID, TorrentState
│   │       │   ├── TransferStats.swift    # TransferStats, FileProgress
│   │       │   ├── FileEntry.swift        # FileEntry, FilePriority enum
│   │       │   └── Peer.swift             # Peer model
│   │       ├── TorrentEvent.swift         # TorrentEvent enum
│   │       ├── TorrentManager.swift       # Main actor — owns lt_session, polling, event stream
│   │       ├── TorrentSource.swift        # Enum: .magnet(String) | .file(URL)
│   │       ├── EngineSettings.swift       # Codable settings struct (bandwidth, paths, port)
│   │       └── Persistence.swift          # Resume data save/load, settings JSON read/write
│   └── Tests/
│       └── OmniTorrentEngineTests/
│           ├── TorrentModelsTests.swift   # Domain type tests
│           ├── TorrentEventTests.swift    # Event enum tests
│           ├── PersistenceTests.swift     # Settings serialization tests
│           └── TorrentManagerTests.swift  # Integration tests with real libtorrent session
│
├── OmniTorrent/                           # App target (in Xcode project)
│   ├── OmniTorrentApp.swift              # @main, scene, URL scheme handler, window config
│   ├── ViewModels/
│   │   ├── TorrentListViewModel.swift    # Observes engine events, drives torrent list
│   │   └── SettingsViewModel.swift       # Reads/writes EngineSettings
│   ├── Views/
│   │   ├── ContentView.swift             # NavigationSplitView root
│   │   ├── SidebarView.swift             # Filter categories + speed stats
│   │   ├── TorrentListView.swift         # Scrollable list of torrent cards
│   │   ├── TorrentCardView.swift         # Individual torrent row (glass card)
│   │   ├── DetailPanelView.swift         # Tabbed detail panel container
│   │   ├── FilesTabView.swift            # Per-file checkboxes + priority
│   │   ├── PeersTabView.swift            # Connected peers table
│   │   ├── TrackersTabView.swift         # Tracker list
│   │   ├── InfoTabView.swift             # Torrent metadata
│   │   └── SettingsView.swift            # Preferences window (Cmd+,)
│   └── Helpers/
│       ├── FormatHelpers.swift           # Byte formatting, ETA formatting, rate formatting
│       └── StatusColor.swift             # TorrentState → Color mapping
│
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-04-09-omnitorrent-design.md
│       └── plans/
│           └── 2026-04-09-omnitorrent-implementation.md
│
└── .gitignore
```

---

## Chunk 1: Project Scaffolding & LibTorrentKit

### Task 1: Initialize project structure and .gitignore

**Files:**
- Create: `.gitignore`
- Create: `LibTorrentKit/Package.swift`
- Create: `OmniTorrentEngine/Package.swift`

- [ ] **Step 1: Create .gitignore**

```gitignore
# Xcode
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xccheckout
*.moved-aside

# Swift Package Manager
.build/
.swiftpm/
Packages/

# libtorrent build artifacts
LibTorrentKit/lib/
LibTorrentKit/build/

# macOS
.DS_Store
*.dSYM

# App data
*.app
```

- [ ] **Step 2: Create LibTorrentKit Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LibTorrentKit",
    platforms: [.macOS(.v26)],
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
            ],
            linkerSettings: [
                .linkedLibrary("torrent-rasterbar", .when(platforms: [.macOS])),
                .linkedLibrary("ssl", .when(platforms: [.macOS])),
                .linkedLibrary("crypto", .when(platforms: [.macOS])),
                .unsafeFlags(["-L../../lib/lib"]),
            ]
        ),
        .testTarget(
            name: "LibTorrentKitTests",
            dependencies: ["LibTorrentKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
```

- [ ] **Step 3: Create OmniTorrentEngine Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniTorrentEngine",
    platforms: [.macOS(.v26)],
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
```

- [ ] **Step 4: Create placeholder source files so packages resolve**

Create `LibTorrentKit/Sources/LibTorrentKit/include/libtorrentkit.h`:
```c
#ifndef LIBTORRENTKIT_H
#define LIBTORRENTKIT_H

#ifdef __cplusplus
extern "C" {
#endif

// Opaque session handle
typedef struct lt_session_t lt_session_t;

// Session lifecycle
lt_session_t* lt_session_create(void);
void lt_session_destroy(lt_session_t* session);

#ifdef __cplusplus
}
#endif

#endif // LIBTORRENTKIT_H
```

Create `LibTorrentKit/Sources/LibTorrentKit/libtorrentkit.cpp`:
```cpp
#include "libtorrentkit.h"

// Stub implementation — will be filled once libtorrent is compiled
struct lt_session_t {
    // placeholder
};

lt_session_t* lt_session_create(void) {
    return new lt_session_t();
}

void lt_session_destroy(lt_session_t* session) {
    delete session;
}
```

Create `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentManager.swift`:
```swift
import LibTorrentKit

/// Central actor managing the libtorrent session and emitting torrent events.
public actor TorrentManager {
    public init() {}
}
```

- [ ] **Step 5: Verify packages resolve**

Run: `cd LibTorrentKit && swift build 2>&1 | tail -5`
Expected: Build succeeds (stub compiles)

Run: `cd OmniTorrentEngine && swift build 2>&1 | tail -5`
Expected: Build succeeds (depends on LibTorrentKit)

- [ ] **Step 6: Commit**

```bash
git add .gitignore LibTorrentKit/ OmniTorrentEngine/
git commit -m "feat: scaffold LibTorrentKit and OmniTorrentEngine packages"
```

---

### Task 2: Build libtorrent from source

**Files:**
- Create: `LibTorrentKit/build-libtorrent.sh`

- [ ] **Step 1: Create build script**

This script clones libtorrent, compiles it with CMake for macOS arm64, and installs headers + static lib into `LibTorrentKit/lib/`.

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/lib"
LIBTORRENT_VERSION="v2.0.10"

echo "==> Checking dependencies..."
command -v cmake >/dev/null 2>&1 || { echo "cmake required. Install with: brew install cmake"; exit 1; }
command -v brew >/dev/null 2>&1 || { echo "Homebrew required."; exit 1; }

# Ensure boost and openssl are available
BOOST_ROOT="$(brew --prefix boost)"
OPENSSL_ROOT="$(brew --prefix openssl@3)"

if [ ! -d "$BOOST_ROOT" ]; then
    echo "==> Installing boost..."
    brew install boost
    BOOST_ROOT="$(brew --prefix boost)"
fi

if [ ! -d "$OPENSSL_ROOT" ]; then
    echo "==> Installing openssl@3..."
    brew install openssl@3
    OPENSSL_ROOT="$(brew --prefix openssl@3)"
fi

echo "==> Cloning libtorrent $LIBTORRENT_VERSION..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

git clone --depth 1 --branch "$LIBTORRENT_VERSION" \
    https://github.com/arvidn/libtorrent.git

cd libtorrent
mkdir build && cd build

echo "==> Configuring with CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_CXX_STANDARD=17 \
    -DBUILD_SHARED_LIBS=OFF \
    -Dencryption=ON \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
    -DBoost_ROOT="$BOOST_ROOT" \
    -Dpython-bindings=OFF \
    -Dpython-egg-info=OFF

echo "==> Building..."
cmake --build . --config Release -j "$(sysctl -n hw.ncpu)"

echo "==> Installing to $INSTALL_DIR..."
cmake --install .

echo "==> Done! libtorrent installed to $INSTALL_DIR"
echo "    Headers: $INSTALL_DIR/include/"
echo "    Library: $INSTALL_DIR/lib/"
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x LibTorrentKit/build-libtorrent.sh`

- [ ] **Step 3: Run the build script**

Run: `cd LibTorrentKit && ./build-libtorrent.sh`
Expected: libtorrent compiles and installs to `LibTorrentKit/lib/`. This may take 5-10 minutes.

- [ ] **Step 4: Verify the build output**

Run: `ls LibTorrentKit/lib/lib/libtorrent-rasterbar.a && echo "OK"`
Expected: `OK` — static library exists

Run: `ls LibTorrentKit/lib/include/libtorrent/session.hpp && echo "OK"`
Expected: `OK` — headers installed

- [ ] **Step 5: Commit**

```bash
git add LibTorrentKit/build-libtorrent.sh
git commit -m "feat: add libtorrent build script (CMake, arm64, static)"
```

---

### Task 3: Implement LibTorrentKit C bridge — session and torrent management

**Files:**
- Modify: `LibTorrentKit/Sources/LibTorrentKit/include/libtorrentkit.h`
- Modify: `LibTorrentKit/Sources/LibTorrentKit/libtorrentkit.cpp`

- [ ] **Step 1: Write the full C header**

Replace `LibTorrentKit/Sources/LibTorrentKit/include/libtorrentkit.h`:

```c
#ifndef LIBTORRENTKIT_H
#define LIBTORRENTKIT_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Opaque handles ---
typedef struct lt_session_t lt_session_t;
typedef struct lt_torrent_t lt_torrent_t;

// --- Session lifecycle ---
lt_session_t* lt_session_create(int listen_port);
void lt_session_destroy(lt_session_t* session);

// --- Session settings ---
void lt_session_set_download_limit(lt_session_t* session, int bytes_per_sec);
void lt_session_set_upload_limit(lt_session_t* session, int bytes_per_sec);

// --- Adding torrents ---
// Returns NULL on failure. Caller owns the lt_torrent_t.
lt_torrent_t* lt_add_torrent_magnet(lt_session_t* session, const char* magnet_uri, const char* save_path);
lt_torrent_t* lt_add_torrent_file(lt_session_t* session, const char* torrent_path, const char* save_path);
lt_torrent_t* lt_add_torrent_resume(lt_session_t* session, const void* resume_data, int resume_data_len, const char* save_path);

// --- Torrent control ---
void lt_torrent_pause(lt_torrent_t* torrent);
void lt_torrent_resume(lt_torrent_t* torrent);
void lt_torrent_remove(lt_session_t* session, lt_torrent_t* torrent, bool delete_files);
void lt_torrent_set_sequential(lt_torrent_t* torrent, bool sequential);
void lt_torrent_set_download_limit(lt_torrent_t* torrent, int bytes_per_sec);
void lt_torrent_set_upload_limit(lt_torrent_t* torrent, int bytes_per_sec);

// --- Torrent status ---
typedef struct {
    int state;            // maps to libtorrent::torrent_status::state_t
    float progress;       // 0.0 to 1.0
    int64_t total_size;
    int64_t total_done;
    int download_rate;    // bytes/sec
    int upload_rate;      // bytes/sec
    int num_peers;
    int num_seeds;
    bool is_paused;
    bool is_seeding;
    bool is_finished;
    int64_t all_time_upload;
    int64_t all_time_download;
    const char* name;     // valid until next lt_get_status call
    const char* save_path;
    const char* info_hash; // hex string, valid until next call
} lt_torrent_status_t;

// --- Tracker info ---
typedef struct {
    const char* url;      // valid until next lt_get_trackers call
    int tier;
    int num_peers;
    bool is_working;
} lt_tracker_info_t;

int lt_get_tracker_count(lt_torrent_t* torrent);
bool lt_get_trackers(lt_torrent_t* torrent, lt_tracker_info_t* out_trackers, int max_count);

bool lt_get_status(lt_torrent_t* torrent, lt_torrent_status_t* out_status);

// --- File management ---
typedef struct {
    const char* path;     // valid until next lt_get_files call
    int64_t size;
    float progress;       // 0.0 to 1.0
    int priority;         // 0=skip, 4=normal, 7=high
} lt_file_info_t;

int lt_get_file_count(lt_torrent_t* torrent);
bool lt_get_files(lt_torrent_t* torrent, lt_file_info_t* out_files, int count);
void lt_set_file_priority(lt_torrent_t* torrent, int file_index, int priority);

// --- Peers ---
typedef struct {
    const char* ip;       // valid until next lt_get_peers call
    int port;
    const char* client;   // valid until next lt_get_peers call
    int download_rate;
    int upload_rate;
    float progress;
} lt_peer_info_t;

int lt_get_peer_count(lt_torrent_t* torrent);
bool lt_get_peers(lt_torrent_t* torrent, lt_peer_info_t* out_peers, int max_count);

// --- Resume data ---
// Returns a malloc'd buffer. Caller must free() it. Sets out_len.
void* lt_save_resume_data(lt_torrent_t* torrent, int* out_len);

// --- Enumerate active torrents ---
int lt_session_torrent_count(lt_session_t* session);
lt_torrent_t* lt_session_get_torrent(lt_session_t* session, int index);

#ifdef __cplusplus
}
#endif

#endif // LIBTORRENTKIT_H
```

- [ ] **Step 2: Write the C++ implementation**

Replace `LibTorrentKit/Sources/LibTorrentKit/libtorrentkit.cpp` with the full implementation. This file wraps libtorrent's C++ API:

```cpp
#include "libtorrentkit.h"

#include <libtorrent/session.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/bencode.hpp>
#include <libtorrent/peer_info.hpp>
#include <libtorrent/session_params.hpp>
#include <libtorrent/settings_pack.hpp>

#include <vector>
#include <string>
#include <fstream>
#include <mutex>
#include <cstring>

namespace lt = libtorrent;

// --- Internal structures ---

struct lt_torrent_t {
    lt::torrent_handle handle;
    std::string name_buf;
    std::string save_path_buf;
    std::string info_hash_buf;
    std::vector<std::string> file_path_bufs;
    std::vector<std::string> peer_ip_bufs;
    std::vector<std::string> peer_client_bufs;
};

struct lt_session_t {
    lt::session session;
    std::vector<lt_torrent_t*> torrents;
    std::mutex mutex;

    lt_session_t(int port) {
        lt::settings_pack sp;
        sp.set_int(lt::settings_pack::alert_mask,
            lt::alert_category::status |
            lt::alert_category::storage |
            lt::alert_category::error);
        std::string iface = "0.0.0.0:" + std::to_string(port);
        sp.set_str(lt::settings_pack::listen_interfaces, iface);
        session = lt::session(sp);
    }
};

// --- Session lifecycle ---

lt_session_t* lt_session_create(int listen_port) {
    try {
        return new lt_session_t(listen_port);
    } catch (...) {
        return nullptr;
    }
}

void lt_session_destroy(lt_session_t* session) {
    if (!session) return;
    std::lock_guard<std::mutex> lock(session->mutex);
    for (auto* t : session->torrents) {
        delete t;
    }
    session->torrents.clear();
    delete session;
}

// --- Session settings ---

void lt_session_set_download_limit(lt_session_t* session, int bytes_per_sec) {
    if (!session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::download_rate_limit, bytes_per_sec);
    session->session.apply_settings(sp);
}

void lt_session_set_upload_limit(lt_session_t* session, int bytes_per_sec) {
    if (!session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::upload_rate_limit, bytes_per_sec);
    session->session.apply_settings(sp);
}

// --- Adding torrents ---

static lt_torrent_t* wrap_handle(lt_session_t* session, lt::torrent_handle h) {
    auto* t = new lt_torrent_t();
    t->handle = h;
    std::lock_guard<std::mutex> lock(session->mutex);
    session->torrents.push_back(t);
    return t;
}

lt_torrent_t* lt_add_torrent_magnet(lt_session_t* session, const char* magnet_uri, const char* save_path) {
    if (!session || !magnet_uri || !save_path) return nullptr;
    try {
        lt::add_torrent_params atp = lt::parse_magnet_uri(magnet_uri);
        atp.save_path = save_path;
        lt::torrent_handle h = session->session.add_torrent(atp);
        return wrap_handle(session, h);
    } catch (...) {
        return nullptr;
    }
}

lt_torrent_t* lt_add_torrent_file(lt_session_t* session, const char* torrent_path, const char* save_path) {
    if (!session || !torrent_path || !save_path) return nullptr;
    try {
        lt::add_torrent_params atp;
        atp.ti = std::make_shared<lt::torrent_info>(torrent_path);
        atp.save_path = save_path;
        lt::torrent_handle h = session->session.add_torrent(atp);
        return wrap_handle(session, h);
    } catch (...) {
        return nullptr;
    }
}

lt_torrent_t* lt_add_torrent_resume(lt_session_t* session, const void* resume_data, int resume_data_len, const char* save_path) {
    if (!session || !resume_data || resume_data_len <= 0) return nullptr;
    try {
        auto buf = std::vector<char>(
            static_cast<const char*>(resume_data),
            static_cast<const char*>(resume_data) + resume_data_len
        );
        lt::add_torrent_params atp = lt::read_resume_data(buf);
        if (save_path) atp.save_path = save_path;
        lt::torrent_handle h = session->session.add_torrent(atp);
        return wrap_handle(session, h);
    } catch (...) {
        return nullptr;
    }
}

// --- Torrent control ---

void lt_torrent_pause(lt_torrent_t* torrent) {
    if (!torrent) return;
    torrent->handle.pause();
}

void lt_torrent_resume(lt_torrent_t* torrent) {
    if (!torrent) return;
    torrent->handle.resume();
}

void lt_torrent_remove(lt_session_t* session, lt_torrent_t* torrent, bool delete_files) {
    if (!session || !torrent) return;
    lt::remove_flags_t flags = {};
    if (delete_files) flags = lt::session::delete_files;
    session->session.remove_torrent(torrent->handle, flags);
    {
        std::lock_guard<std::mutex> lock(session->mutex);
        auto& v = session->torrents;
        v.erase(std::remove(v.begin(), v.end(), torrent), v.end());
    }
    delete torrent;
}

void lt_torrent_set_sequential(lt_torrent_t* torrent, bool sequential) {
    if (!torrent) return;
    if (sequential)
        torrent->handle.set_flags(lt::torrent_flags::sequential_download);
    else
        torrent->handle.unset_flags(lt::torrent_flags::sequential_download);
}

void lt_torrent_set_download_limit(lt_torrent_t* torrent, int bytes_per_sec) {
    if (!torrent) return;
    torrent->handle.set_download_limit(bytes_per_sec);
}

void lt_torrent_set_upload_limit(lt_torrent_t* torrent, int bytes_per_sec) {
    if (!torrent) return;
    torrent->handle.set_upload_limit(bytes_per_sec);
}

// --- Torrent status ---

bool lt_get_status(lt_torrent_t* torrent, lt_torrent_status_t* out) {
    if (!torrent || !out) return false;
    try {
        auto st = torrent->handle.status();
        out->state = static_cast<int>(st.state);
        out->progress = st.progress;
        out->total_size = st.total_wanted;
        out->total_done = st.total_wanted_done;
        out->download_rate = st.download_rate;
        out->upload_rate = st.upload_rate;
        out->num_peers = st.num_peers;
        out->num_seeds = st.num_seeds;
        out->is_paused = (st.flags & lt::torrent_flags::paused) != 0;
        out->is_seeding = st.is_seeding;
        out->is_finished = st.is_finished;
        out->all_time_upload = st.all_time_upload;
        out->all_time_download = st.all_time_download;

        torrent->name_buf = st.name;
        out->name = torrent->name_buf.c_str();

        torrent->save_path_buf = st.save_path;
        out->save_path = torrent->save_path_buf.c_str();

        std::ostringstream oss;
        oss << st.info_hashes.get_best();
        torrent->info_hash_buf = oss.str();
        out->info_hash = torrent->info_hash_buf.c_str();

        return true;
    } catch (...) {
        return false;
    }
}

// --- File management ---

int lt_get_file_count(lt_torrent_t* torrent) {
    if (!torrent) return 0;
    auto ti = torrent->handle.torrent_file();
    if (!ti) return 0;
    return ti->num_files();
}

bool lt_get_files(lt_torrent_t* torrent, lt_file_info_t* out_files, int count) {
    if (!torrent || !out_files || count <= 0) return false;
    try {
        auto ti = torrent->handle.torrent_file();
        if (!ti) return false;

        auto& fs = ti->files();
        std::vector<int64_t> progress;
        torrent->handle.file_progress(progress);
        auto priorities = torrent->handle.get_file_priorities();

        torrent->file_path_bufs.resize(count);

        int n = std::min(count, ti->num_files());
        for (int i = 0; i < n; i++) {
            torrent->file_path_bufs[i] = fs.file_path(lt::file_index_t(i));
            out_files[i].path = torrent->file_path_bufs[i].c_str();
            out_files[i].size = fs.file_size(lt::file_index_t(i));
            out_files[i].progress = (out_files[i].size > 0)
                ? static_cast<float>(progress[i]) / static_cast<float>(out_files[i].size)
                : 1.0f;
            out_files[i].priority = static_cast<int>(priorities[i]);
        }
        return true;
    } catch (...) {
        return false;
    }
}

void lt_set_file_priority(lt_torrent_t* torrent, int file_index, int priority) {
    if (!torrent) return;
    torrent->handle.file_priority(
        lt::file_index_t(file_index),
        lt::download_priority_t(static_cast<uint8_t>(priority))
    );
}

// --- Peers ---

int lt_get_peer_count(lt_torrent_t* torrent) {
    if (!torrent) return 0;
    return torrent->handle.status().num_peers;
}

bool lt_get_peers(lt_torrent_t* torrent, lt_peer_info_t* out_peers, int max_count) {
    if (!torrent || !out_peers || max_count <= 0) return false;
    try {
        std::vector<lt::peer_info> peers;
        torrent->handle.get_peer_info(peers);

        int n = std::min(max_count, static_cast<int>(peers.size()));
        torrent->peer_ip_bufs.resize(n);
        torrent->peer_client_bufs.resize(n);

        for (int i = 0; i < n; i++) {
            torrent->peer_ip_bufs[i] = peers[i].ip.address().to_string();
            out_peers[i].ip = torrent->peer_ip_bufs[i].c_str();
            out_peers[i].port = peers[i].ip.port();
            torrent->peer_client_bufs[i] = peers[i].client;
            out_peers[i].client = torrent->peer_client_bufs[i].c_str();
            out_peers[i].download_rate = peers[i].down_speed;
            out_peers[i].upload_rate = peers[i].up_speed;
            out_peers[i].progress = peers[i].progress;
        }
        return true;
    } catch (...) {
        return false;
    }
}

// --- Trackers ---

int lt_get_tracker_count(lt_torrent_t* torrent) {
    if (!torrent) return 0;
    auto trackers = torrent->handle.trackers();
    return static_cast<int>(trackers.size());
}

bool lt_get_trackers(lt_torrent_t* torrent, lt_tracker_info_t* out_trackers, int max_count) {
    if (!torrent || !out_trackers || max_count <= 0) return false;
    try {
        auto trackers = torrent->handle.trackers();
        int n = std::min(max_count, static_cast<int>(trackers.size()));
        // Store URLs in torrent struct to keep pointers valid
        static thread_local std::vector<std::string> tracker_url_bufs;
        tracker_url_bufs.resize(n);
        for (int i = 0; i < n; i++) {
            tracker_url_bufs[i] = trackers[i].url;
            out_trackers[i].url = tracker_url_bufs[i].c_str();
            out_trackers[i].tier = trackers[i].tier;
            // num_peers from endpoints if available
            int peers = 0;
            for (auto& ep : trackers[i].endpoints) {
                for (auto& info : ep.info_hashes) {
                    peers += info.scrape_complete + info.scrape_incomplete;
                }
            }
            out_trackers[i].num_peers = peers;
            out_trackers[i].is_working = !trackers[i].endpoints.empty() &&
                trackers[i].endpoints[0].info_hashes[0].fails == 0;
        }
        return true;
    } catch (...) {
        return false;
    }
}

// --- Resume data ---

void* lt_save_resume_data(lt_torrent_t* torrent, int* out_len) {
    if (!torrent || !out_len) return nullptr;
    try {
        // Use torrent_handle::write_resume_data() which returns add_torrent_params directly
        lt::add_torrent_params atp = torrent->handle.write_resume_data();
        std::vector<char> buf = lt::write_resume_data_buf(atp);
        void* result = malloc(buf.size());
        if (result) {
            memcpy(result, buf.data(), buf.size());
            *out_len = static_cast<int>(buf.size());
        }
        return result;
    } catch (...) {
        *out_len = 0;
        return nullptr;
    }
}

// --- Enumerate active torrents ---

int lt_session_torrent_count(lt_session_t* session) {
    if (!session) return 0;
    std::lock_guard<std::mutex> lock(session->mutex);
    return static_cast<int>(session->torrents.size());
}

lt_torrent_t* lt_session_get_torrent(lt_session_t* session, int index) {
    if (!session) return nullptr;
    std::lock_guard<std::mutex> lock(session->mutex);
    if (index < 0 || index >= static_cast<int>(session->torrents.size())) return nullptr;
    return session->torrents[index];
}
```

- [ ] **Step 3: Update Package.swift linker settings with correct paths**

After libtorrent is built, verify the actual install paths and update `Package.swift` if needed. The key paths are:
- Headers: `LibTorrentKit/lib/include/`
- Static lib: `LibTorrentKit/lib/lib/`
- Also need boost and openssl from Homebrew

Update LibTorrentKit `Package.swift` linker settings:
```swift
linkerSettings: [
    .unsafeFlags([
        "-L\(Context.packageDirectory)/lib/lib",
        "-L/opt/homebrew/lib",
    ]),
    .linkedLibrary("torrent-rasterbar"),
    .linkedLibrary("ssl"),
    .linkedLibrary("crypto"),
    .linkedLibrary("boost_system"),
]
```

And cxxSettings:
```swift
cxxSettings: [
    .unsafeFlags([
        "-I\(Context.packageDirectory)/lib/include",
        "-I/opt/homebrew/include",
    ]),
    .define("TORRENT_USE_OPENSSL", to: "1"),
    .define("BOOST_ASIO_HAS_STD_INVOKE_RESULT", to: "1"),
]
```

- [ ] **Step 4: Build and verify**

Run: `cd LibTorrentKit && swift build 2>&1 | tail -10`
Expected: Build succeeds — the C++ file compiles and links against libtorrent

- [ ] **Step 5: Write basic smoke test**

Create `LibTorrentKit/Tests/LibTorrentKitTests/LibTorrentKitTests.swift`:
```swift
import Testing
@testable import LibTorrentKit

@Test func sessionCreateDestroy() {
    let session = lt_session_create(6881)
    #expect(session != nil)
    lt_session_destroy(session)
}

@Test func sessionTorrentCountStartsAtZero() {
    let session = lt_session_create(6882)!
    #expect(lt_session_torrent_count(session) == 0)
    lt_session_destroy(session)
}
```

- [ ] **Step 6: Run tests**

Run: `cd LibTorrentKit && swift test 2>&1 | tail -10`
Expected: 2 tests pass

- [ ] **Step 7: Commit**

```bash
git add LibTorrentKit/
git commit -m "feat: implement LibTorrentKit C bridge over libtorrent"
```

---

## Chunk 2: OmniTorrentEngine — Domain Types & TorrentManager

### Task 4: Define domain model types

**Files:**
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Models/Torrent.swift`
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Models/TransferStats.swift`
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Models/FileEntry.swift`
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Models/Peer.swift`
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentEvent.swift`
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentSource.swift`
- Test: `OmniTorrentEngine/Tests/OmniTorrentEngineTests/TorrentModelsTests.swift`

- [ ] **Step 1: Write tests for domain types**

```swift
import Testing
@testable import OmniTorrentEngine

@Test func torrentStateFromLibtorrentRawValue() {
    #expect(TorrentState.from(ltState: 1, isPaused: false) == .checking)
    #expect(TorrentState.from(ltState: 3, isPaused: false) == .downloading)
    #expect(TorrentState.from(ltState: 5, isPaused: false) == .seeding)
    #expect(TorrentState.from(ltState: 3, isPaused: true) == .paused)
}

@Test func filePriorityRawValues() {
    #expect(FilePriority.skip.ltValue == 0)
    #expect(FilePriority.normal.ltValue == 4)
    #expect(FilePriority.high.ltValue == 7)
}

@Test func torrentSourceMagnet() {
    let source = TorrentSource.magnet("magnet:?xt=urn:btih:abc123")
    if case .magnet(let uri) = source {
        #expect(uri.contains("btih"))
    } else {
        Issue.record("Expected magnet source")
    }
}

@Test func transferStatsFormatsETA() {
    let stats = TransferStats(
        downloadRate: 1_000_000,
        uploadRate: 500_000,
        totalDownloaded: 500_000_000,
        totalUploaded: 250_000_000,
        peersConnected: 10,
        eta: 3661
    )
    #expect(stats.downloadRate == 1_000_000)
    #expect(stats.eta == 3661)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd OmniTorrentEngine && swift test 2>&1 | tail -5`
Expected: FAIL — types don't exist yet

- [ ] **Step 3: Implement domain types**

`Models/Torrent.swift`:
```swift
import Foundation

public typealias TorrentID = UUID

public enum TorrentState: Sendable, Equatable {
    case checking
    case downloading
    case seeding
    case paused
    case queued
    case error

    public static func from(ltState: Int, isPaused: Bool) -> TorrentState {
        if isPaused { return .paused }
        switch ltState {
        case 1, 2: return .checking    // checking_files, checking_resume_data
        case 3:    return .downloading  // downloading
        case 4:    return .downloading  // finished (still has peers)
        case 5:    return .seeding      // seeding
        default:   return .queued
        }
    }
}

public struct Torrent: Identifiable, Sendable {
    public let id: TorrentID
    public var name: String
    public var state: TorrentState
    public var progress: Float
    public var totalSize: Int64
    public var savePath: String
    public var files: [FileEntry]
    public var stats: TransferStats
    public var infoHash: String

    public init(
        id: TorrentID = TorrentID(),
        name: String,
        state: TorrentState = .queued,
        progress: Float = 0,
        totalSize: Int64 = 0,
        savePath: String = "",
        files: [FileEntry] = [],
        stats: TransferStats = .zero,
        infoHash: String = ""
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.progress = progress
        self.totalSize = totalSize
        self.savePath = savePath
        self.files = files
        self.stats = stats
        self.infoHash = infoHash
    }
}
```

`Models/TransferStats.swift`:
```swift
public struct TransferStats: Sendable, Equatable {
    public var downloadRate: Int
    public var uploadRate: Int
    public var totalDownloaded: Int64
    public var totalUploaded: Int64
    public var peersConnected: Int
    public var eta: Int // seconds, -1 if unknown

    public static let zero = TransferStats(
        downloadRate: 0, uploadRate: 0,
        totalDownloaded: 0, totalUploaded: 0,
        peersConnected: 0, eta: -1
    )

    public init(downloadRate: Int, uploadRate: Int, totalDownloaded: Int64, totalUploaded: Int64, peersConnected: Int, eta: Int) {
        self.downloadRate = downloadRate
        self.uploadRate = uploadRate
        self.totalDownloaded = totalDownloaded
        self.totalUploaded = totalUploaded
        self.peersConnected = peersConnected
        self.eta = eta
    }
}

public struct FileProgress: Sendable {
    public let index: Int
    public let progress: Float

    public init(index: Int, progress: Float) {
        self.index = index
        self.progress = progress
    }
}
```

`Models/FileEntry.swift`:
```swift
public enum FilePriority: Sendable, Equatable {
    case skip
    case normal
    case high

    public var ltValue: Int {
        switch self {
        case .skip: return 0
        case .normal: return 4
        case .high: return 7
        }
    }

    public static func from(ltValue: Int) -> FilePriority {
        switch ltValue {
        case 0: return .skip
        case 7: return .high
        default: return .normal
        }
    }
}

public struct FileEntry: Sendable, Identifiable {
    public let id: Int // file index
    public var path: String
    public var size: Int64
    public var progress: Float
    public var priority: FilePriority

    public init(id: Int, path: String, size: Int64, progress: Float = 0, priority: FilePriority = .normal) {
        self.id = id
        self.path = path
        self.size = size
        self.progress = progress
        self.priority = priority
    }
}
```

`Models/Peer.swift`:
```swift
public struct Peer: Sendable, Identifiable {
    public var id: String { "\(ip):\(port)" }
    public var ip: String
    public var port: Int
    public var client: String
    public var downloadRate: Int
    public var uploadRate: Int
    public var progress: Float

    public init(ip: String, port: Int, client: String, downloadRate: Int, uploadRate: Int, progress: Float) {
        self.ip = ip
        self.port = port
        self.client = client
        self.downloadRate = downloadRate
        self.uploadRate = uploadRate
        self.progress = progress
    }
}
```

`TorrentEvent.swift`:
```swift
public enum TorrentEvent: Sendable {
    case added(Torrent)
    case stateChanged(id: TorrentID, state: TorrentState)
    case statsUpdated(id: TorrentID, stats: TransferStats)
    case fileProgress(id: TorrentID, files: [FileProgress])
    case peersUpdated(id: TorrentID, peers: [Peer])
    case removed(TorrentID)
    case error(id: TorrentID, TorrentError)
}

public enum TorrentError: Error, Sendable {
    case invalidMagnetURI
    case fileNotFound
    case sessionError(String)
    case addFailed(String)
}
```

`TorrentSource.swift`:
```swift
import Foundation

public enum TorrentSource: Sendable {
    case magnet(String)
    case file(URL)
}
```

- [ ] **Step 4: Run tests**

Run: `cd OmniTorrentEngine && swift test 2>&1 | tail -10`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add OmniTorrentEngine/Sources/ OmniTorrentEngine/Tests/
git commit -m "feat: define OmniTorrentEngine domain types and events"
```

---

### Task 5: Implement EngineSettings and Persistence

**Files:**
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/EngineSettings.swift`
- Create: `OmniTorrentEngine/Sources/OmniTorrentEngine/Persistence.swift`
- Test: `OmniTorrentEngine/Tests/OmniTorrentEngineTests/PersistenceTests.swift`

- [ ] **Step 1: Write tests**

```swift
import Testing
import Foundation
@testable import OmniTorrentEngine

@Test func settingsRoundTrip() throws {
    let settings = EngineSettings(
        downloadPath: "/Users/test/Downloads",
        listenPort: 6881,
        maxDownloadRate: 1_000_000,
        maxUploadRate: 500_000,
        maxConnections: 200,
        launchAtLogin: false
    )
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(EngineSettings.self, from: data)
    #expect(decoded.downloadPath == settings.downloadPath)
    #expect(decoded.listenPort == settings.listenPort)
    #expect(decoded.maxDownloadRate == settings.maxDownloadRate)
}

@Test func settingsDefaults() {
    let settings = EngineSettings.defaults
    #expect(settings.listenPort == 6881)
    #expect(settings.maxDownloadRate == 0) // 0 = unlimited
    #expect(settings.maxUploadRate == 0)
}

@Test func persistenceSaveAndLoadSettings() throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let settings = EngineSettings(
        downloadPath: "/tmp/test",
        listenPort: 7777,
        maxDownloadRate: 0,
        maxUploadRate: 0,
        maxConnections: 100
    )
    try persistence.saveSettings(settings)
    let loaded = try persistence.loadSettings()
    #expect(loaded.listenPort == 7777)
    #expect(loaded.downloadPath == "/tmp/test")
}

@Test func persistenceResumeData() throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let testData = Data([0x01, 0x02, 0x03, 0x04])
    let id = TorrentID()

    try persistence.saveResumeData(testData, for: id)
    let loaded = try persistence.loadResumeData(for: id)
    #expect(loaded == testData)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd OmniTorrentEngine && swift test 2>&1 | tail -5`
Expected: FAIL

- [ ] **Step 3: Implement EngineSettings**

```swift
import Foundation

public struct EngineSettings: Codable, Sendable, Equatable {
    public var downloadPath: String
    public var listenPort: Int
    public var maxDownloadRate: Int  // bytes/sec, 0 = unlimited
    public var maxUploadRate: Int    // bytes/sec, 0 = unlimited
    public var maxConnections: Int
    public var launchAtLogin: Bool

    public static let defaults = EngineSettings(
        downloadPath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first ?? "~/Downloads",
        listenPort: 6881,
        maxDownloadRate: 0,
        maxUploadRate: 0,
        maxConnections: 200,
        launchAtLogin: false
    )

    public init(downloadPath: String, listenPort: Int, maxDownloadRate: Int, maxUploadRate: Int, maxConnections: Int, launchAtLogin: Bool = false) {
        self.downloadPath = downloadPath
        self.listenPort = listenPort
        self.maxDownloadRate = maxDownloadRate
        self.maxUploadRate = maxUploadRate
        self.maxConnections = maxConnections
        self.launchAtLogin = launchAtLogin
    }
}
```

- [ ] **Step 4: Implement Persistence**

```swift
import Foundation

public struct Persistence: Sendable {
    private let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    public static var appSupport: Persistence {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OmniTorrent")
        return Persistence(baseDirectory: dir)
    }

    // MARK: - Settings

    private var settingsURL: URL {
        baseDirectory.appendingPathComponent("settings.json")
    }

    public func saveSettings(_ settings: EngineSettings) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func loadSettings() throws -> EngineSettings {
        let data = try Data(contentsOf: settingsURL)
        return try JSONDecoder().decode(EngineSettings.self, from: data)
    }

    public func loadSettingsOrDefaults() -> EngineSettings {
        (try? loadSettings()) ?? .defaults
    }

    // MARK: - Resume Data

    private var resumeDirectory: URL {
        baseDirectory.appendingPathComponent("resume")
    }

    public func saveResumeData(_ data: Data, for id: TorrentID) throws {
        try FileManager.default.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
        let fileURL = resumeDirectory.appendingPathComponent("\(id.uuidString).resume")
        try data.write(to: fileURL, options: .atomic)
    }

    public func loadResumeData(for id: TorrentID) throws -> Data {
        let fileURL = resumeDirectory.appendingPathComponent("\(id.uuidString).resume")
        return try Data(contentsOf: fileURL)
    }

    public func allResumeDataFiles() -> [(id: TorrentID, url: URL)] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: resumeDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return contents.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            guard let id = TorrentID(uuidString: name) else { return nil }
            return (id, url)
        }
    }

    public func deleteResumeData(for id: TorrentID) throws {
        let fileURL = resumeDirectory.appendingPathComponent("\(id.uuidString).resume")
        try FileManager.default.removeItem(at: fileURL)
    }
}
```

- [ ] **Step 5: Run tests**

Run: `cd OmniTorrentEngine && swift test 2>&1 | tail -10`
Expected: All tests pass (previous 4 + new 4 = 8)

- [ ] **Step 6: Commit**

```bash
git add OmniTorrentEngine/
git commit -m "feat: implement EngineSettings and Persistence (settings + resume data)"
```

---

### Task 6: Implement TorrentManager actor

**Files:**
- Modify: `OmniTorrentEngine/Sources/OmniTorrentEngine/TorrentManager.swift`
- Test: `OmniTorrentEngine/Tests/OmniTorrentEngineTests/TorrentManagerTests.swift`

- [ ] **Step 1: Write integration test**

```swift
import Testing
import Foundation
@testable import OmniTorrentEngine

@Test func managerStartsAndStops() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let manager = TorrentManager(settings: .defaults, persistence: persistence)
    await manager.start()
    let count = await manager.torrents.count
    #expect(count == 0)
    await manager.stop()
}

@Test func managerGlobalStats() async throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let persistence = Persistence(baseDirectory: tmpDir)
    let manager = TorrentManager(settings: .defaults, persistence: persistence)
    await manager.start()
    let stats = await manager.globalStats
    #expect(stats.downloadRate == 0)
    #expect(stats.uploadRate == 0)
    await manager.stop()
}
```

- [ ] **Step 2: Run to verify failure**

Run: `cd OmniTorrentEngine && swift test 2>&1 | tail -5`
Expected: FAIL — TorrentManager methods don't exist yet

- [ ] **Step 3: Implement TorrentManager**

Replace `TorrentManager.swift`:

```swift
import Foundation
import LibTorrentKit

public struct GlobalStats: Sendable {
    public var downloadRate: Int
    public var uploadRate: Int
    public var activeTorrents: Int

    public static let zero = GlobalStats(downloadRate: 0, uploadRate: 0, activeTorrents: 0)
}

public actor TorrentManager {
    private var session: OpaquePointer? // lt_session_t*
    private var settings: EngineSettings
    private let persistence: Persistence
    private var pollingTask: Task<Void, Never>?

    // Published state
    public private(set) var torrents: [TorrentID: Torrent] = [:]
    public private(set) var globalStats: GlobalStats = .zero

    // Maps engine torrent IDs to libtorrent handles
    private var handleMap: [TorrentID: OpaquePointer] = [:] // lt_torrent_t*

    // Event stream
    private let eventContinuation: AsyncStream<TorrentEvent>.Continuation
    public let events: AsyncStream<TorrentEvent>

    public init(settings: EngineSettings, persistence: Persistence) {
        self.settings = settings
        self.persistence = persistence

        let (stream, continuation) = AsyncStream<TorrentEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
    }

    // MARK: - Lifecycle

    public func start() {
        guard session == nil else { return }
        session = lt_session_create(Int32(settings.listenPort))

        if settings.maxDownloadRate > 0 {
            lt_session_set_download_limit(session, Int32(settings.maxDownloadRate))
        }
        if settings.maxUploadRate > 0 {
            lt_session_set_upload_limit(session, Int32(settings.maxUploadRate))
        }

        // Load resume data
        for (id, url) in persistence.allResumeDataFiles() {
            guard let data = try? Data(contentsOf: url) else { continue }
            data.withUnsafeBytes { ptr in
                guard let base = ptr.baseAddress else { return }
                if let handle = lt_add_torrent_resume(
                    session, base, Int32(data.count),
                    nil // use save_path from resume data
                ) {
                    handleMap[id] = handle
                    torrents[id] = Torrent(id: id, name: "Loading...", state: .checking)
                }
            }
        }

        // Start polling
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self?.poll()
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil

        // Save resume data for all torrents
        for (id, handle) in handleMap {
            var len: Int32 = 0
            if let buf = lt_save_resume_data(handle, &len), len > 0 {
                let data = Data(bytes: buf, count: Int(len))
                free(buf)
                try? persistence.saveResumeData(data, for: id)
            }
        }

        if let session {
            lt_session_destroy(session)
        }
        session = nil
        handleMap.removeAll()
        eventContinuation.finish()
    }

    // MARK: - Adding Torrents

    public func addTorrent(source: TorrentSource, savePath: String? = nil) throws -> TorrentID {
        guard let session else { throw TorrentError.sessionError("Session not started") }
        let path = savePath ?? settings.downloadPath

        let handle: OpaquePointer?
        switch source {
        case .magnet(let uri):
            handle = lt_add_torrent_magnet(session, uri, path)
        case .file(let url):
            handle = lt_add_torrent_file(session, url.path, path)
        }

        guard let handle else {
            throw TorrentError.addFailed("Failed to add torrent")
        }

        let id = TorrentID()
        handleMap[id] = handle
        let torrent = Torrent(id: id, name: "Loading...", state: .checking)
        torrents[id] = torrent
        eventContinuation.yield(.added(torrent))
        return id
    }

    // MARK: - Torrent Control

    public func pauseTorrent(_ id: TorrentID) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_pause(handle)
    }

    public func resumeTorrent(_ id: TorrentID) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_resume(handle)
    }

    public func removeTorrent(_ id: TorrentID, deleteFiles: Bool = false) {
        guard let handle = handleMap[id], let session else { return }
        lt_torrent_remove(session, handle, deleteFiles)
        handleMap.removeValue(forKey: id)
        torrents.removeValue(forKey: id)
        try? persistence.deleteResumeData(for: id)
        eventContinuation.yield(.removed(id))
    }

    public func setSequentialDownload(_ id: TorrentID, enabled: Bool) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_set_sequential(handle, enabled)
    }

    public func setFilePriority(_ torrentID: TorrentID, fileIndex: Int, priority: FilePriority) {
        guard let handle = handleMap[torrentID] else { return }
        lt_set_file_priority(handle, Int32(fileIndex), Int32(priority.ltValue))
    }

    public func setTorrentDownloadLimit(_ id: TorrentID, bytesPerSec: Int) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_set_download_limit(handle, Int32(bytesPerSec))
    }

    public func setTorrentUploadLimit(_ id: TorrentID, bytesPerSec: Int) {
        guard let handle = handleMap[id] else { return }
        lt_torrent_set_upload_limit(handle, Int32(bytesPerSec))
    }

    // MARK: - Settings

    public func updateSettings(_ newSettings: EngineSettings) {
        settings = newSettings
        if let session {
            lt_session_set_download_limit(session, Int32(newSettings.maxDownloadRate))
            lt_session_set_upload_limit(session, Int32(newSettings.maxUploadRate))
        }
        try? persistence.saveSettings(newSettings)
    }

    // MARK: - File & Peer Info

    public func files(for id: TorrentID) -> [FileEntry] {
        guard let handle = handleMap[id] else { return [] }
        let count = lt_get_file_count(handle)
        guard count > 0 else { return [] }

        var cFiles = [lt_file_info_t](repeating: lt_file_info_t(), count: Int(count))
        guard lt_get_files(handle, &cFiles, count) else { return [] }

        return (0..<Int(count)).map { i in
            FileEntry(
                id: i,
                path: String(cString: cFiles[i].path),
                size: cFiles[i].size,
                progress: cFiles[i].progress,
                priority: FilePriority.from(ltValue: Int(cFiles[i].priority))
            )
        }
    }

    public func peers(for id: TorrentID) -> [Peer] {
        guard let handle = handleMap[id] else { return [] }
        let count = lt_get_peer_count(handle)
        guard count > 0 else { return [] }

        let maxPeers = min(Int(count), 200)
        var cPeers = [lt_peer_info_t](repeating: lt_peer_info_t(), count: maxPeers)
        guard lt_get_peers(handle, &cPeers, Int32(maxPeers)) else { return [] }

        return (0..<maxPeers).map { i in
            Peer(
                ip: String(cString: cPeers[i].ip),
                port: Int(cPeers[i].port),
                client: String(cString: cPeers[i].client),
                downloadRate: Int(cPeers[i].download_rate),
                uploadRate: Int(cPeers[i].upload_rate),
                progress: cPeers[i].progress
            )
        }
    }

    // MARK: - Polling

    private func poll() {
        guard session != nil else { return }

        var totalDown = 0
        var totalUp = 0
        var activeCount = 0

        for (id, handle) in handleMap {
            var status = lt_torrent_status_t()
            guard lt_get_status(handle, &status) else { continue }

            let newState = TorrentState.from(ltState: Int(status.state), isPaused: status.is_paused)
            let name = String(cString: status.name)
            let savePath = String(cString: status.save_path)
            let infoHash = String(cString: status.info_hash)

            let eta: Int
            if status.download_rate > 0 && status.total_size > status.total_done {
                eta = Int(status.total_size - status.total_done) / Int(status.download_rate)
            } else {
                eta = -1
            }

            let stats = TransferStats(
                downloadRate: Int(status.download_rate),
                uploadRate: Int(status.upload_rate),
                totalDownloaded: status.all_time_download,
                totalUploaded: status.all_time_upload,
                peersConnected: Int(status.num_peers),
                eta: eta
            )

            totalDown += Int(status.download_rate)
            totalUp += Int(status.upload_rate)
            if newState == .downloading || newState == .seeding { activeCount += 1 }

            // Diff and emit events
            if let existing = torrents[id] {
                if existing.state != newState {
                    eventContinuation.yield(.stateChanged(id: id, state: newState))
                }
                if existing.stats != stats {
                    eventContinuation.yield(.statsUpdated(id: id, stats: stats))
                }
            }

            // Update stored torrent
            torrents[id] = Torrent(
                id: id,
                name: name.isEmpty ? torrents[id]?.name ?? "Unknown" : name,
                state: newState,
                progress: status.progress,
                totalSize: status.total_size,
                savePath: savePath,
                files: torrents[id]?.files ?? [],
                stats: stats,
                infoHash: infoHash
            )
        }

        globalStats = GlobalStats(
            downloadRate: totalDown,
            uploadRate: totalUp,
            activeTorrents: activeCount
        )
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd OmniTorrentEngine && swift test 2>&1 | tail -10`
Expected: All tests pass (8 previous + 2 new = 10)

- [ ] **Step 5: Commit**

```bash
git add OmniTorrentEngine/
git commit -m "feat: implement TorrentManager actor with polling and event stream"
```

---

## Chunk 3: SwiftUI App — Views & ViewModels

### Task 7: Create Xcode project and app entry point

**Files:**
- Create: `OmniTorrent/OmniTorrentApp.swift`
- Create: `OmniTorrent/Info.plist` (configure in Xcode)

This task requires Xcode. Create a new macOS App project in the `OmniTorrent/` directory:

- [ ] **Step 1: Create the Xcode project**

In Xcode:
1. File > New > Project > macOS > App
2. Product Name: `OmniTorrent`
3. Organization: personal
4. Interface: SwiftUI
5. Language: Swift
6. Save to the `OmniTorrent/` root directory
7. Add local package dependencies: `LibTorrentKit` and `OmniTorrentEngine`

- [ ] **Step 2: Write the app entry point**

```swift
import SwiftUI
import OmniTorrentEngine

class AppDelegate: NSObject, NSApplicationDelegate {
    var viewModel: TorrentListViewModel?

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "magnet" {
                viewModel?.addTorrent(source: .magnet(url.absoluteString))
            } else if url.pathExtension == "torrent" {
                viewModel?.addTorrent(source: .file(url))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let manager = viewModel?.manager {
            // Synchronous wait for resume data save
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await manager.stop()
                semaphore.signal()
            }
            semaphore.wait(timeout: .now() + 5)
        }
    }
}

@main
struct OmniTorrentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = TorrentListViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .preferredGlassBackgroundEffect()
                .onAppear { appDelegate.viewModel = viewModel }
        }
        .defaultSize(width: 1000, height: 700)

        Settings {
            SettingsView(viewModel: SettingsViewModel(manager: viewModel.manager))
        }
    }
}
```

- [ ] **Step 3: Configure Info.plist for magnet links and .torrent files**

Add to Info.plist:
- `CFBundleURLTypes`: URL scheme `magnet`
- `CFBundleDocumentTypes`: `.torrent` file type (`application/x-bittorrent`)

- [ ] **Step 4: Build to verify project compiles**

Run: Cmd+B in Xcode
Expected: Build succeeds (views will be stubs initially)

- [ ] **Step 5: Commit**

```bash
git add OmniTorrent/
git commit -m "feat: create OmniTorrent Xcode project with package dependencies"
```

---

### Task 8: Implement helpers and TorrentListViewModel

**Files:**
- Create: `OmniTorrent/Helpers/FormatHelpers.swift`
- Create: `OmniTorrent/Helpers/StatusColor.swift`
- Create: `OmniTorrent/ViewModels/TorrentListViewModel.swift`

- [ ] **Step 1: Implement FormatHelpers**

```swift
import Foundation

enum FormatHelpers {
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func formatRate(_ bytesPerSec: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }

    static func formatETA(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(seconds)s"
    }

    static func formatProgress(_ progress: Float) -> String {
        "\(Int(progress * 100))%"
    }

    static func formatRatio(uploaded: Int64, downloaded: Int64) -> String {
        guard downloaded > 0 else { return "∞" }
        let ratio = Double(uploaded) / Double(downloaded)
        return String(format: "%.1f", ratio)
    }
}
```

- [ ] **Step 2: Implement StatusColor**

```swift
import SwiftUI
import OmniTorrentEngine

extension TorrentState {
    var color: Color {
        switch self {
        case .downloading: return .blue
        case .seeding:     return .green
        case .paused:      return .secondary
        case .queued:      return .orange
        case .checking:    return .purple
        case .error:       return .red
        }
    }

    var label: String {
        switch self {
        case .downloading: return "Downloading"
        case .seeding:     return "Seeding"
        case .paused:      return "Paused"
        case .queued:      return "Queued"
        case .checking:    return "Checking"
        case .error:       return "Error"
        }
    }
}
```

- [ ] **Step 3: Implement TorrentListViewModel**

```swift
import Foundation
import SwiftUI
import OmniTorrentEngine

enum SidebarFilter: String, CaseIterable {
    case all = "All Downloads"
    case seeding = "Seeding"
    case paused = "Paused"
    case completed = "Completed"
}

@Observable
final class TorrentListViewModel {
    let manager: TorrentManager
    private let persistence: Persistence

    var torrents: [Torrent] = []
    var globalStats: GlobalStats = .zero
    var selectedTorrentID: TorrentID?
    var sidebarFilter: SidebarFilter = .all
    var searchText: String = ""

    var filteredTorrents: [Torrent] {
        var result = torrents

        switch sidebarFilter {
        case .all: break
        case .seeding:
            result = result.filter { $0.state == .seeding }
        case .paused:
            result = result.filter { $0.state == .paused }
        case .completed:
            result = result.filter { $0.state == .seeding && $0.progress >= 1.0 }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var selectedTorrent: Torrent? {
        guard let id = selectedTorrentID else { return nil }
        return torrents.first { $0.id == id }
    }

    init() {
        self.persistence = Persistence.appSupport
        self.manager = TorrentManager(
            settings: persistence.loadSettingsOrDefaults(),
            persistence: persistence
        )
        Task { await start() }
    }

    private func start() async {
        await manager.start()

        // Observe events
        for await event in await manager.events {
            await MainActor.run {
                handleEvent(event)
            }
        }
    }

    @MainActor
    private func handleEvent(_ event: TorrentEvent) {
        // Refresh full torrent list from manager
        Task {
            let allTorrents = await manager.torrents
            self.torrents = Array(allTorrents.values).sorted { $0.name < $1.name }
            self.globalStats = await manager.globalStats
        }
    }

    // MARK: - Actions

    func addTorrent(source: TorrentSource) {
        Task {
            _ = try? await manager.addTorrent(source: source)
        }
    }

    func pauseTorrent(_ id: TorrentID) {
        Task { await manager.pauseTorrent(id) }
    }

    func resumeTorrent(_ id: TorrentID) {
        Task { await manager.resumeTorrent(id) }
    }

    func removeTorrent(_ id: TorrentID, deleteFiles: Bool = false) {
        Task { await manager.removeTorrent(id, deleteFiles: deleteFiles) }
    }

    func setSequentialDownload(_ id: TorrentID, enabled: Bool) {
        Task { await manager.setSequentialDownload(id, enabled: enabled) }
    }

    func setFilePriority(_ torrentID: TorrentID, fileIndex: Int, priority: FilePriority) {
        Task { await manager.setFilePriority(torrentID, fileIndex: fileIndex, priority: priority) }
    }

    func files(for id: TorrentID) async -> [FileEntry] {
        await manager.files(for: id)
    }

    func peers(for id: TorrentID) async -> [Peer] {
        await manager.peers(for: id)
    }
}
```

- [ ] **Step 4: Build**

Run: Cmd+B in Xcode
Expected: Compiles (views are still stubs)

- [ ] **Step 5: Commit**

```bash
git add OmniTorrent/
git commit -m "feat: add FormatHelpers, StatusColor, and TorrentListViewModel"
```

---

### Task 9: Implement SwiftUI views — Sidebar and ContentView

**Files:**
- Create: `OmniTorrent/Views/ContentView.swift`
- Create: `OmniTorrent/Views/SidebarView.swift`

- [ ] **Step 1: Implement SidebarView**

```swift
import SwiftUI
import OmniTorrentEngine

struct SidebarView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        List(selection: $viewModel.sidebarFilter) {
            Section("Transfers") {
                ForEach(SidebarFilter.allCases, id: \.self) { filter in
                    Label(filter.rawValue, systemImage: filter.icon)
                        .tag(filter)
                }
            }
        }
        .glassEffect(.regular)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Text("↓ \(FormatHelpers.formatRate(viewModel.globalStats.downloadRate))")
                Text("↑ \(FormatHelpers.formatRate(viewModel.globalStats.uploadRate))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.thin)
        }
    }
}

extension SidebarFilter {
    var icon: String {
        switch self {
        case .all:       return "arrow.down.circle"
        case .seeding:   return "arrow.up.circle"
        case .paused:    return "pause.circle"
        case .completed: return "checkmark.circle"
        }
    }
}
```

- [ ] **Step 2: Implement ContentView**

```swift
import SwiftUI
import OmniTorrentEngine

struct ContentView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            VSplitView {
                TorrentListView(viewModel: viewModel)
                    .frame(minHeight: 200)

                if viewModel.selectedTorrent != nil {
                    DetailPanelView(viewModel: viewModel)
                        .frame(minHeight: 200)
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search torrents...")
        .onOpenURL { url in
            if url.scheme == "magnet" {
                viewModel.addTorrent(source: .magnet(url.absoluteString))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url, url.pathExtension == "torrent" {
                        Task { @MainActor in
                            viewModel.addTorrent(source: .file(url))
                        }
                    }
                }
            }
            return true
        }
        .toolbar {
            ToolbarItem {
                Button(action: openTorrentFile) {
                    Image(systemName: "plus")
                }
                .glassEffect(.thin)
            }
        }
    }

    private func openTorrentFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "torrent")!]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    viewModel.addTorrent(source: .file(url))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: Cmd+B in Xcode
Expected: Compiles (TorrentListView and DetailPanelView still needed)

- [ ] **Step 4: Commit**

```bash
git add OmniTorrent/Views/
git commit -m "feat: implement ContentView and SidebarView with liquid glass"
```

---

### Task 10: Implement TorrentCardView and TorrentListView

**Files:**
- Create: `OmniTorrent/Views/TorrentCardView.swift`
- Create: `OmniTorrent/Views/TorrentListView.swift`

- [ ] **Step 1: Implement TorrentCardView**

```swift
import SwiftUI
import OmniTorrentEngine

struct TorrentCardView: View {
    let torrent: Torrent
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(torrent.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(torrent.state.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(torrent.state.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(torrent.state.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 16) {
                Text(FormatHelpers.formatBytes(torrent.totalSize))

                if torrent.state == .downloading {
                    Text("· \(FormatHelpers.formatProgress(torrent.progress))")
                    Text("↓ \(FormatHelpers.formatRate(torrent.stats.downloadRate))")
                    Text("ETA \(FormatHelpers.formatETA(torrent.stats.eta))")
                } else if torrent.state == .seeding {
                    Text("↑ \(FormatHelpers.formatRate(torrent.stats.uploadRate))")
                    Text("Ratio: \(FormatHelpers.formatRatio(uploaded: torrent.stats.totalUploaded, downloaded: torrent.stats.totalDownloaded))")
                }

                Text("\(torrent.stats.peersConnected) peers")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            ProgressView(value: torrent.progress)
                .tint(torrent.state.color)
                .scaleEffect(y: 0.5)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.clear)
                .glassEffect(.thin)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
            }
        }
        .contextMenu {
            TorrentContextMenu(torrent: torrent)
        }
    }
}

struct TorrentContextMenu: View {
    let torrent: Torrent

    @Environment(TorrentListViewModel.self) private var viewModel

    var body: some View {
        if torrent.state == .paused {
            Button("Resume") { viewModel.resumeTorrent(torrent.id) }
        } else {
            Button("Pause") { viewModel.pauseTorrent(torrent.id) }
        }

        Divider()

        Toggle("Sequential Download", isOn: Binding(
            get: { false }, // Track this state in Torrent model if needed
            set: { viewModel.setSequentialDownload(torrent.id, enabled: $0) }
        ))

        Menu("Download Limit") {
            Button("Unlimited") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 0) }
            Button("100 KB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 100_000) }
            Button("500 KB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 500_000) }
            Button("1 MB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 1_000_000) }
            Button("5 MB/s") { viewModel.setTorrentDownloadLimit(torrent.id, bytesPerSec: 5_000_000) }
        }

        Menu("Upload Limit") {
            Button("Unlimited") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 0) }
            Button("100 KB/s") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 100_000) }
            Button("500 KB/s") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 500_000) }
            Button("1 MB/s") { viewModel.setTorrentUploadLimit(torrent.id, bytesPerSec: 1_000_000) }
        }

        Divider()

        Button("Reveal in Finder") {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: torrent.savePath)
        }

        Divider()

        Button("Remove", role: .destructive) {
            viewModel.removeTorrent(torrent.id)
        }
        Button("Remove & Delete Files", role: .destructive) {
            viewModel.removeTorrent(torrent.id, deleteFiles: true)
        }
    }
}
```

Also add the missing ViewModel methods:
```swift
// In TorrentListViewModel, add:
func setTorrentDownloadLimit(_ id: TorrentID, bytesPerSec: Int) {
    Task { await manager.setTorrentDownloadLimit(id, bytesPerSec: bytesPerSec) }
}

func setTorrentUploadLimit(_ id: TorrentID, bytesPerSec: Int) {
    Task { await manager.setTorrentUploadLimit(id, bytesPerSec: bytesPerSec) }
}
```

- [ ] **Step 2: Implement TorrentListView**

```swift
import SwiftUI
import OmniTorrentEngine

struct TorrentListView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(viewModel.filteredTorrents) { torrent in
                    TorrentCardView(
                        torrent: torrent,
                        isSelected: viewModel.selectedTorrentID == torrent.id
                    )
                    .onTapGesture {
                        viewModel.selectedTorrentID = torrent.id
                    }
                }
            }
            .padding(10)
        }
        .overlay {
            if viewModel.filteredTorrents.isEmpty {
                ContentUnavailableView {
                    Label("No Torrents", systemImage: "arrow.down.circle.dotted")
                } description: {
                    Text("Drop a .torrent file or paste a magnet link to get started.")
                }
            }
        }
        .environment(viewModel)
    }
}
```

- [ ] **Step 3: Build**

Run: Cmd+B in Xcode
Expected: Compiles (DetailPanelView still needed as stub)

- [ ] **Step 4: Commit**

```bash
git add OmniTorrent/Views/
git commit -m "feat: implement TorrentCardView and TorrentListView with glass effect"
```

---

### Task 11: Implement Detail Panel views

**Files:**
- Create: `OmniTorrent/Views/DetailPanelView.swift`
- Create: `OmniTorrent/Views/FilesTabView.swift`
- Create: `OmniTorrent/Views/PeersTabView.swift`
- Create: `OmniTorrent/Views/TrackersTabView.swift`
- Create: `OmniTorrent/Views/InfoTabView.swift`

- [ ] **Step 1: Implement DetailPanelView**

```swift
import SwiftUI
import OmniTorrentEngine

enum DetailTab: String, CaseIterable {
    case files = "Files"
    case peers = "Peers"
    case trackers = "Trackers"
    case info = "Info"
}

struct DetailPanelView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var selectedTab: DetailTab = .files

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            Group {
                switch selectedTab {
                case .files:
                    FilesTabView(viewModel: viewModel)
                case .peers:
                    PeersTabView(viewModel: viewModel)
                case .trackers:
                    TrackersTabView(viewModel: viewModel)
                case .info:
                    InfoTabView(viewModel: viewModel)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.clear)
                .glassEffect(.regular)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}
```

- [ ] **Step 2: Implement FilesTabView**

```swift
import SwiftUI
import OmniTorrentEngine

struct FilesTabView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var files: [FileEntry] = []

    var body: some View {
        List(files) { file in
            HStack {
                Toggle(isOn: Binding(
                    get: { file.priority != .skip },
                    set: { enabled in
                        let priority: FilePriority = enabled ? .normal : .skip
                        if let id = viewModel.selectedTorrentID {
                            viewModel.setFilePriority(id, fileIndex: file.id, priority: priority)
                        }
                    }
                )) {
                    Text(file.path)
                        .font(.system(size: 12))
                        .foregroundStyle(file.priority == .skip ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(FormatHelpers.formatBytes(file.size))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { file.priority },
                    set: { newPriority in
                        if let id = viewModel.selectedTorrentID {
                            viewModel.setFilePriority(id, fileIndex: file.id, priority: newPriority)
                        }
                    }
                )) {
                    Text("Skip").tag(FilePriority.skip)
                    Text("Normal").tag(FilePriority.normal)
                    Text("High").tag(FilePriority.high)
                }
                .frame(width: 80)
            }
        }
        .task(id: viewModel.selectedTorrentID) {
            guard let id = viewModel.selectedTorrentID else { return }
            files = await viewModel.files(for: id)
        }
    }
}
```

- [ ] **Step 3: Implement PeersTabView**

```swift
import SwiftUI
import OmniTorrentEngine

struct PeersTabView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var peers: [Peer] = []

    var body: some View {
        Table(peers) {
            TableColumn("IP") { peer in
                Text(peer.ip).font(.system(size: 11, design: .monospaced))
            }
            .width(min: 100, ideal: 140)

            TableColumn("Client") { peer in
                Text(peer.client).font(.system(size: 11))
            }
            .width(min: 80, ideal: 120)

            TableColumn("↓") { peer in
                Text(FormatHelpers.formatRate(peer.downloadRate)).font(.system(size: 11))
            }
            .width(60)

            TableColumn("↑") { peer in
                Text(FormatHelpers.formatRate(peer.uploadRate)).font(.system(size: 11))
            }
            .width(60)

            TableColumn("Progress") { peer in
                Text(FormatHelpers.formatProgress(peer.progress)).font(.system(size: 11))
            }
            .width(60)
        }
        .task(id: viewModel.selectedTorrentID) {
            guard let id = viewModel.selectedTorrentID else { return }
            peers = await viewModel.peers(for: id)
        }
    }
}
```

- [ ] **Step 4: Implement TrackersTabView**

```swift
import SwiftUI
import OmniTorrentEngine

struct TrackerInfo: Identifiable, Sendable {
    let id: String // url
    let url: String
    let tier: Int
    let numPeers: Int
    let isWorking: Bool
}

struct TrackersTabView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var trackers: [TrackerInfo] = []

    var body: some View {
        Table(trackers) {
            TableColumn("URL") { tracker in
                Text(tracker.url).font(.system(size: 11, design: .monospaced))
            }
            .width(min: 200, ideal: 400)

            TableColumn("Tier") { tracker in
                Text("\(tracker.tier)").font(.system(size: 11))
            }
            .width(40)

            TableColumn("Peers") { tracker in
                Text("\(tracker.numPeers)").font(.system(size: 11))
            }
            .width(50)

            TableColumn("Status") { tracker in
                Text(tracker.isWorking ? "Working" : "Not connected")
                    .font(.system(size: 11))
                    .foregroundStyle(tracker.isWorking ? .green : .secondary)
            }
            .width(90)
        }
        .task(id: viewModel.selectedTorrentID) {
            guard let id = viewModel.selectedTorrentID else { return }
            trackers = await viewModel.trackers(for: id)
        }
    }
}
```

Also add `trackers(for:)` to `TorrentManager` and `TorrentListViewModel`:

In `TorrentManager.swift`, add:
```swift
public func trackers(for id: TorrentID) -> [TrackerInfo] {
    guard let handle = handleMap[id] else { return [] }
    let count = lt_get_tracker_count(handle)
    guard count > 0 else { return [] }

    var cTrackers = [lt_tracker_info_t](repeating: lt_tracker_info_t(), count: Int(count))
    guard lt_get_trackers(handle, &cTrackers, count) else { return [] }

    return (0..<Int(count)).map { i in
        TrackerInfo(
            id: String(cString: cTrackers[i].url),
            url: String(cString: cTrackers[i].url),
            tier: Int(cTrackers[i].tier),
            numPeers: Int(cTrackers[i].num_peers),
            isWorking: cTrackers[i].is_working
        )
    }
}
```

In `TorrentListViewModel.swift`, add:
```swift
func trackers(for id: TorrentID) async -> [TrackerInfo] {
    await manager.trackers(for: id)
}
```

- [ ] **Step 5: Implement InfoTabView**

```swift
import SwiftUI
import OmniTorrentEngine

struct InfoTabView: View {
    @Bindable var viewModel: TorrentListViewModel

    var body: some View {
        if let torrent = viewModel.selectedTorrent {
            Form {
                LabeledContent("Name", value: torrent.name)
                LabeledContent("Info Hash", value: torrent.infoHash)
                LabeledContent("Total Size", value: FormatHelpers.formatBytes(torrent.totalSize))
                LabeledContent("Save Path", value: torrent.savePath)
                LabeledContent("Progress", value: FormatHelpers.formatProgress(torrent.progress))
                LabeledContent("State", value: torrent.state.label)
                LabeledContent("Downloaded", value: FormatHelpers.formatBytes(torrent.stats.totalDownloaded))
                LabeledContent("Uploaded", value: FormatHelpers.formatBytes(torrent.stats.totalUploaded))
                LabeledContent("Peers", value: "\(torrent.stats.peersConnected)")
            }
            .font(.system(size: 12))
            .padding()
        }
    }
}
```

- [ ] **Step 6: Build**

Run: Cmd+B in Xcode
Expected: Compiles

- [ ] **Step 7: Commit**

```bash
git add OmniTorrent/Views/
git commit -m "feat: implement DetailPanelView with Files, Peers, Trackers, and Info tabs"
```

---

### Task 12: Implement SettingsView

**Files:**
- Create: `OmniTorrent/Views/SettingsView.swift`
- Create: `OmniTorrent/ViewModels/SettingsViewModel.swift`

- [ ] **Step 1: Implement SettingsViewModel**

```swift
import Foundation
import OmniTorrentEngine

@Observable
final class SettingsViewModel {
    private let manager: TorrentManager

    var downloadPath: String
    var listenPort: Int
    var maxDownloadRate: Int
    var maxUploadRate: Int
    var maxConnections: Int
    var launchAtLogin: Bool

    init(manager: TorrentManager) {
        self.manager = manager
        let persistence = Persistence.appSupport
        let settings = persistence.loadSettingsOrDefaults()
        self.downloadPath = settings.downloadPath
        self.listenPort = settings.listenPort
        self.maxDownloadRate = settings.maxDownloadRate
        self.maxUploadRate = settings.maxUploadRate
        self.maxConnections = settings.maxConnections
        self.launchAtLogin = settings.launchAtLogin
    }

    func save() {
        let settings = EngineSettings(
            downloadPath: downloadPath,
            listenPort: listenPort,
            maxDownloadRate: maxDownloadRate,
            maxUploadRate: maxUploadRate,
            maxConnections: maxConnections,
            launchAtLogin: launchAtLogin
        )
        Task { await manager.updateSettings(settings) }
    }
}
```

- [ ] **Step 2: Implement SettingsView**

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    LabeledContent("Download Location") {
                        HStack {
                            Text(viewModel.downloadPath)
                                .lineLimit(1)
                                .truncationMode(.head)
                            Button("Choose...") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                if panel.runModal() == .OK, let url = panel.url {
                                    viewModel.downloadPath = url.path
                                    viewModel.save()
                                }
                            }
                        }
                    }
                    Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                        .onChange(of: viewModel.launchAtLogin) { viewModel.save() }
                }
                .padding()
            }

            Tab("Transfers", systemImage: "arrow.up.arrow.down") {
                Form {
                    TextField("Max Download (KB/s, 0=unlimited)",
                              value: $viewModel.maxDownloadRate,
                              format: .number)
                    TextField("Max Upload (KB/s, 0=unlimited)",
                              value: $viewModel.maxUploadRate,
                              format: .number)
                }
                .padding()
                .onChange(of: viewModel.maxDownloadRate) { viewModel.save() }
                .onChange(of: viewModel.maxUploadRate) { viewModel.save() }
            }

            Tab("Connection", systemImage: "network") {
                Form {
                    TextField("Listen Port", value: $viewModel.listenPort, format: .number)
                    TextField("Max Connections", value: $viewModel.maxConnections, format: .number)
                }
                .padding()
                .onChange(of: viewModel.listenPort) { viewModel.save() }
                .onChange(of: viewModel.maxConnections) { viewModel.save() }
            }
        }
        .frame(width: 450, height: 250)
    }
}
```

- [ ] **Step 3: Build and run**

Run: Cmd+R in Xcode
Expected: App launches with liquid glass window. Cmd+, opens settings.

- [ ] **Step 4: Commit**

```bash
git add OmniTorrent/
git commit -m "feat: implement SettingsView with General, Transfers, and Connection tabs"
```

---

## Chunk 4: Polish & Integration

### Task 13: Add keyboard shortcuts and final polish

**Files:**
- Modify: `OmniTorrent/Views/ContentView.swift`
- Modify: `OmniTorrent/OmniTorrentApp.swift`

- [ ] **Step 1: Add keyboard shortcuts to ContentView**

Add to ContentView body:
```swift
.keyboardShortcut(.delete, modifiers: []) {
    if let id = viewModel.selectedTorrentID {
        viewModel.removeTorrent(id)
    }
}
.onKeyPress(.space) {
    guard let torrent = viewModel.selectedTorrent else { return .ignored }
    if torrent.state == .paused {
        viewModel.resumeTorrent(torrent.id)
    } else {
        viewModel.pauseTorrent(torrent.id)
    }
    return .handled
}
```

- [ ] **Step 2: Add menu bar commands to OmniTorrentApp**

Add a `commands` modifier to the WindowGroup:
```swift
.commands {
    CommandGroup(replacing: .newItem) {
        Button("Open Torrent...") {
            // Post notification or use FocusedValue to trigger open panel
        }
        .keyboardShortcut("o")
    }
}
```

- [ ] **Step 3: Test end-to-end**

1. Build and run (Cmd+R)
2. Verify liquid glass renders on sidebar and content area
3. Drop a .torrent file onto the window — verify it starts downloading
4. Click a torrent — verify detail panel appears
5. Right-click — verify context menu
6. Cmd+, — verify settings window opens
7. Quit app — verify no crashes (resume data saved)

- [ ] **Step 4: Commit**

```bash
git add OmniTorrent/
git commit -m "feat: add keyboard shortcuts, menu commands, and graceful shutdown"
```

---

### Task 14: Final build verification

- [ ] **Step 1: Clean build**

Run: Cmd+Shift+K (Clean), then Cmd+B (Build)
Expected: Clean build succeeds with no warnings

- [ ] **Step 2: Run all engine tests**

Run: `cd OmniTorrentEngine && swift test`
Expected: All 10 tests pass

- [ ] **Step 3: Run the app**

Run: Cmd+R
Expected: App launches, liquid glass sidebar visible, ready to accept torrents

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final build verification — OmniTorrent v0.1"
```

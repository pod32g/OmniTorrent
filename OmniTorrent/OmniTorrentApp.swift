import SwiftUI
import OmniTorrentEngine

extension Scene {
    func windowGlass() -> some Scene {
        if #available(macOS 26, *) {
            return self.windowStyle(.automatic)
        } else {
            return self
        }
    }
}

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
                .onAppear { appDelegate.viewModel = viewModel }
        }
        .defaultSize(width: 1000, height: 700)
        .windowGlass()
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Torrent...") {
                    NotificationCenter.default.post(name: .openTorrentFile, object: nil)
                }
                .keyboardShortcut("o")
            }
        }


        Settings {
            SettingsView(viewModel: SettingsViewModel(manager: viewModel.manager))
        }
    }
}

import SwiftUI
import UserNotifications
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

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var viewModel: TorrentListViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let showAction = UNNotificationAction(
            identifier: "SHOW_IN_FINDER",
            title: "Show in Finder",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: "TORRENT_COMPLETE",
            actions: [showAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "SHOW_IN_FINDER" {
            if let savePath = response.notification.request.content.userInfo["savePath"] as? String {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: savePath)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "magnet" {
                viewModel?.addTorrent(source: .magnet(url.absoluteString))
            } else if url.pathExtension == "torrent" {
                viewModel?.addTorrent(source: .file(url))
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Re-show window when dock icon is clicked with no windows open
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let manager = viewModel?.manager {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                await manager.stop()
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 1)
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

        MenuBarExtra {
            MenuBarDropdownView(viewModel: viewModel)
        } label: {
            Text("\u{2193} \(FormatHelpers.formatRate(viewModel.globalStats.downloadRate))  \u{2191} \(FormatHelpers.formatRate(viewModel.globalStats.uploadRate))")
        }
    }
}

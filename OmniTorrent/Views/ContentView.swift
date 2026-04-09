import SwiftUI
import UniformTypeIdentifiers
import OmniTorrentEngine

extension Notification.Name {
    static let openTorrentFile = Notification.Name("openTorrentFile")
}

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
        .onReceive(NotificationCenter.default.publisher(for: .openTorrentFile)) { _ in
            openTorrentFile()
        }
        .toolbar {
            ToolbarItem {
                addButton
            }
        }
        .background {
            // Space bar: pause/resume selected torrent
            Button("") {
                guard let torrent = viewModel.selectedTorrent else { return }
                if torrent.state == .paused {
                    viewModel.resumeTorrent(torrent.id)
                } else {
                    viewModel.pauseTorrent(torrent.id)
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)

            // Delete: remove selected torrent
            Button("") {
                if let id = viewModel.selectedTorrentID {
                    viewModel.removeTorrent(id)
                }
            }
            .keyboardShortcut(.delete, modifiers: [])
            .opacity(0)
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if #available(macOS 26, *) {
            Button(action: openTorrentFile) {
                Image(systemName: "plus")
            }
            .buttonStyle(.glass)
        } else {
            Button(action: openTorrentFile) {
                Image(systemName: "plus")
            }
        }
    }

    private func openTorrentFile() {
        let panel = NSOpenPanel()
        if let torrentType = UTType(filenameExtension: "torrent") {
            panel.allowedContentTypes = [torrentType]
        }
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

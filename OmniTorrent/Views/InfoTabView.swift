import SwiftUI
import OmniTorrentEngine

struct InfoTabView: View {
    @Bindable var viewModel: TorrentListViewModel
    @State private var options = TorrentOptions()

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

                Section("On Complete") {
                    Picker("Action", selection: Binding(
                        get: { options.completionAction },
                        set: { newAction in
                            options.completionAction = newAction
                            if let id = viewModel.selectedTorrentID {
                                viewModel.setTorrentOptions(options, for: id)
                            }
                        }
                    )) {
                        Text("Do Nothing").tag(CompletionAction.doNothing)
                        Text("Open File").tag(CompletionAction.openFile)
                        Text("Reveal in Finder").tag(CompletionAction.revealInFinder)
                    }
                    LabeledContent("Move To") {
                        HStack {
                            Text(options.moveToPath ?? "None")
                                .foregroundStyle(options.moveToPath == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.head)
                            Button("Choose...") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                if panel.runModal() == .OK, let url = panel.url {
                                    options.moveToPath = url.path
                                    if let id = viewModel.selectedTorrentID {
                                        viewModel.setTorrentOptions(options, for: id)
                                    }
                                }
                            }
                            if options.moveToPath != nil {
                                Button("Clear") {
                                    options.moveToPath = nil
                                    if let id = viewModel.selectedTorrentID {
                                        viewModel.setTorrentOptions(options, for: id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .font(.system(size: 12))
            .padding()
            .task(id: viewModel.selectedTorrentID) {
                guard let id = viewModel.selectedTorrentID else { return }
                options = await viewModel.torrentOptions(for: id)
            }
        }
    }
}

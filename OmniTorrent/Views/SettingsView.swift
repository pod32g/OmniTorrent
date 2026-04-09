import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isDefaultClient = false

    var body: some View {
        TabView {
            Form {
                Section("File Associations") {
                    HStack {
                        if isDefaultClient {
                            Text("OmniTorrent is the default .torrent handler")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("OmniTorrent is not the default .torrent handler")
                                .foregroundStyle(.secondary)
                            Button("Set as Default") {
                                setAsDefaultTorrentClient()
                            }
                        }
                    }
                    HStack {
                        if isMagnetDefault() {
                            Text("OmniTorrent handles magnet links")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("OmniTorrent does not handle magnet links")
                                .foregroundStyle(.secondary)
                            Button("Set as Default") {
                                setAsDefaultMagnetHandler()
                            }
                        }
                    }
                }
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
                LabeledContent("Watch Folder") {
                    HStack {
                        Text(viewModel.watchFolderPath ?? "Disabled")
                            .foregroundStyle(viewModel.watchFolderPath == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                viewModel.watchFolderPath = url.path
                                viewModel.save()
                            }
                        }
                        if viewModel.watchFolderPath != nil {
                            Button("Disable") {
                                viewModel.watchFolderPath = nil
                                viewModel.save()
                            }
                        }
                    }
                }
            }
            .padding()
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Speed Limits") {
                    TextField("Max Download (KB/s, 0=unlimited)",
                              value: $viewModel.maxDownloadRate,
                              format: .number)
                    TextField("Max Upload (KB/s, 0=unlimited)",
                              value: $viewModel.maxUploadRate,
                              format: .number)
                }
                Section("Queue Limits") {
                    TextField("Max Active Downloads (0=unlimited)",
                              value: $viewModel.maxActiveDownloads,
                              format: .number)
                    TextField("Max Active Seeds (0=unlimited)",
                              value: $viewModel.maxActiveSeeds,
                              format: .number)
                }
            }
            .padding()
            .onChange(of: viewModel.maxDownloadRate) { viewModel.save() }
            .onChange(of: viewModel.maxUploadRate) { viewModel.save() }
            .onChange(of: viewModel.maxActiveDownloads) { viewModel.save() }
            .onChange(of: viewModel.maxActiveSeeds) { viewModel.save() }
            .tabItem { Label("Transfers", systemImage: "arrow.up.arrow.down") }

            Form {
                TextField("Listen Port", value: $viewModel.listenPort, format: .number)
                TextField("Max Connections", value: $viewModel.maxConnections, format: .number)
            }
            .padding()
            .onChange(of: viewModel.listenPort) { viewModel.save() }
            .onChange(of: viewModel.maxConnections) { viewModel.save() }
            .tabItem { Label("Connection", systemImage: "network") }
        }
        .frame(width: 450, height: 300)
        .onAppear { isDefaultClient = checkIsDefaultTorrentClient() }
    }

    private func checkIsDefaultTorrentClient() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let handler = LSCopyDefaultRoleHandlerForContentType(
                  "org.bittorrent.torrent" as CFString,
                  .viewer
              )?.takeRetainedValue() as String? else { return false }
        return handler == bundleID
    }

    private func setAsDefaultTorrentClient() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultRoleHandlerForContentType(
            "org.bittorrent.torrent" as CFString,
            .all,
            bundleID as CFString
        )
        isDefaultClient = true
    }

    private func isMagnetDefault() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let handler = LSCopyDefaultHandlerForURLScheme("magnet" as CFString)?.takeRetainedValue() as String? else { return false }
        return handler == bundleID
    }

    private func setAsDefaultMagnetHandler() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("magnet" as CFString, bundleID as CFString)
    }
}

import SwiftUI
import UniformTypeIdentifiers
import OmniTorrentEngine

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

            ScheduleTabView(viewModel: viewModel)
                .tabItem { Label("Schedule", systemImage: "clock") }
        }
        .frame(width: 500, height: 340)
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

// MARK: - Schedule Tab

private struct ScheduleTabView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(viewModel.bandwidthSchedule.indices, id: \.self) { index in
                    ScheduleSlotRow(slot: $viewModel.bandwidthSchedule[index]) {
                        viewModel.bandwidthSchedule.remove(at: index)
                        viewModel.save()
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button {
                    viewModel.bandwidthSchedule.append(
                        ScheduleSlot(startHour: 9, endHour: 17, maxDownloadRate: 0, maxUploadRate: 0)
                    )
                    viewModel.save()
                } label: {
                    Label("Add Slot", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Spacer()

                if viewModel.bandwidthSchedule.isEmpty {
                    Text("No schedule — global limits always apply")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.trailing, 12)
                }
            }
        }
        .onChange(of: viewModel.bandwidthSchedule) { viewModel.save() }
    }
}

private struct ScheduleSlotRow: View {
    @Binding var slot: ScheduleSlot
    let onRemove: () -> Void

    private let hours = Array(0..<24)

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $slot.startHour) {
                ForEach(hours, id: \.self) { h in
                    Text(String(format: "%d:00", h)).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: 68)

            Text("–")
                .foregroundStyle(.secondary)

            Picker("", selection: $slot.endHour) {
                ForEach(hours, id: \.self) { h in
                    Text(String(format: "%d:00", h)).tag(h)
                }
            }
            .labelsHidden()
            .frame(width: 68)

            Spacer()

            Image(systemName: "arrow.down")
                .foregroundStyle(.secondary)
                .font(.caption)
            RateField(label: "Down", value: $slot.maxDownloadRate)

            Image(systemName: "arrow.up")
                .foregroundStyle(.secondary)
                .font(.caption)
            RateField(label: "Up", value: $slot.maxUploadRate)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

private struct RateField: View {
    let label: String
    @Binding var value: Int

    // Stored in KB/s for display; 0 means unlimited
    @State private var text: String = ""

    var body: some View {
        TextField(label, text: $text)
            .frame(width: 80)
            .onAppear { text = value == 0 ? "" : "\(value / 1024)" }
            .onChange(of: text) {
                if text.isEmpty {
                    value = 0
                } else if let kb = Int(text), kb >= 0 {
                    value = kb * 1024
                }
            }
            .overlay(alignment: .trailing) {
                if text.isEmpty {
                    Text("∞")
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                        .allowsHitTesting(false)
                }
            }
    }
}

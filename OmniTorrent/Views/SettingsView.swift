import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
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
            .tabItem { Label("General", systemImage: "gearshape") }

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
        .frame(width: 450, height: 250)
    }
}

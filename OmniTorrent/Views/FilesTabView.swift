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

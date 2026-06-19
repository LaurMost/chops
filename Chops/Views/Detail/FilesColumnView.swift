import SwiftUI

/// Left rail of the skill detail pane: a file tree of the skill's bundled
/// resources. Full file management (new file/folder, rename, delete) is gated by
/// `isReadOnly`. `SKILL.md` can't be deleted or renamed here.
struct FilesColumnView: View {
    let rootURL: URL
    @Binding var selection: URL?
    let isReadOnly: Bool
    let nodes: [SkillFileNode]
    let onChange: () -> Void

    @State private var prompt: FilePrompt?
    @State private var promptText: String = ""
    @State private var errorMessage: String?

    private enum FilePrompt: Identifiable {
        case newFile(directory: URL)
        case newFolder(directory: URL)
        case rename(url: URL)

        var id: String {
            switch self {
            case .newFile(let dir): "new-file-\(dir.path)"
            case .newFolder(let dir): "new-folder-\(dir.path)"
            case .rename(let url): "rename-\(url.path)"
            }
        }

        var title: String {
            switch self {
            case .newFile: "New File"
            case .newFolder: "New Folder"
            case .rename: "Rename"
            }
        }

        var initialText: String {
            switch self {
            case .newFile, .newFolder: ""
            case .rename(let url): url.lastPathComponent
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                OutlineGroup(nodes, children: \.children) { node in
                    fileRow(node)
                        .tag(node.url)
                }
            }
            .listStyle(.sidebar)

            Divider()
            railToolbar
        }
        .frame(minWidth: 180, idealWidth: 220)
        .alert(
            prompt?.title ?? "",
            isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }),
            presenting: prompt
        ) { prompt in
            TextField("Name", text: $promptText)
            Button("Cancel", role: .cancel) {}
            Button(confirmLabel(prompt)) { commit(prompt) }
        }
        .alert(
            "File Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startPrompt(_ newPrompt: FilePrompt) {
        promptText = newPrompt.initialText
        prompt = newPrompt
    }

    private func fileRow(_ node: SkillFileNode) -> some View {
        Label(node.name, systemImage: icon(for: node))
            .lineLimit(1)
            .contextMenu { contextMenu(for: node) }
    }

    @ViewBuilder
    private func contextMenu(for node: SkillFileNode) -> some View {
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }
        if !isReadOnly {
            let targetDir = node.isDirectory ? node.url : node.url.deletingLastPathComponent()
            Divider()
            Button("New File…") { startPrompt(.newFile(directory: targetDir)) }
            Button("New Folder…") { startPrompt(.newFolder(directory: targetDir)) }
            if node.name != "SKILL.md" {
                Button("Rename…") { startPrompt(.rename(url: node.url)) }
                Divider()
                Button("Delete", role: .destructive) { delete(node.url) }
            }
        }
    }

    private var railToolbar: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                startPrompt(.newFile(directory: rootURL))
            } label: {
                Image(systemName: "doc.badge.plus")
            }
            .help("New File")
            .accessibilityLabel("New File")

            Button {
                startPrompt(.newFolder(directory: rootURL))
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("New Folder")
            .accessibilityLabel("New Folder")

            Spacer()

            Button {
                if let selection, selection.lastPathComponent != "SKILL.md" {
                    delete(selection)
                }
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete Selected")
            .accessibilityLabel("Delete Selected")
            .disabled(selection == nil || selection?.lastPathComponent == "SKILL.md")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .opacity(isReadOnly ? 0 : 1)
        .frame(height: isReadOnly ? 0 : nil)
        .disabled(isReadOnly)
    }

    // MARK: - Operations

    private func confirmLabel(_ prompt: FilePrompt) -> String {
        switch prompt {
        case .newFile, .newFolder: "Create"
        case .rename: "Rename"
        }
    }

    private func commit(_ prompt: FilePrompt) {
        do {
            switch prompt {
            case .newFile(let directory):
                let url = try SkillFileOperations.newFile(named: promptText, in: directory, isReadOnly: isReadOnly)
                onChange()
                selection = url
            case .newFolder(let directory):
                try SkillFileOperations.newFolder(named: promptText, in: directory, isReadOnly: isReadOnly)
                onChange()
            case .rename(let url):
                let renamed = try SkillFileOperations.rename(url, to: promptText, isReadOnly: isReadOnly)
                onChange()
                if selection == url { selection = renamed }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ url: URL) {
        do {
            try SkillFileOperations.delete(url, isReadOnly: isReadOnly)
            if selection == url { selection = rootURL.appendingPathComponent("SKILL.md") }
            onChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func icon(for node: SkillFileNode) -> String {
        switch node.kind {
        case .directory: "folder"
        case .text: node.name == "SKILL.md" ? "doc.text.fill" : "doc.text"
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .otherBinary: "doc"
        }
    }
}

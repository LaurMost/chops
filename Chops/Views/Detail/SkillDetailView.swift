import SwiftData
import SwiftUI

struct SkillDetailView: View {
    private enum ActiveAlert: Identifiable {
        case confirmDelete
        case confirmMakeGlobal
        case deleteError(String)
        case makeGlobalError(String)

        var id: String {
            switch self {
            case .confirmDelete:
                return "confirm-delete"
            case .confirmMakeGlobal:
                return "confirm-make-global"
            case .deleteError(let message):
                return "delete-error-\(message)"
            case .makeGlobalError(let message):
                return "make-global-error-\(message)"
            }
        }
    }

    @Bindable var skill: Skill
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @AppStorage("preferPreview") private var preferPreview = false
    @State private var document = SkillEditorDocument()
    @State private var activeAlert: ActiveAlert?
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var showingComposePanel = false
    @State private var fileTree: [SkillFileNode] = []
    @State private var selectedFileURL: URL?
    @ScaledMetric(relativeTo: .body) private var composeButtonSize: CGFloat = 36

    /// Bottom gutter reserved in the editor so text scrolls clear of the floating
    /// compose button (button height + its padding + breathing room).
    private static let composeButtonClearance: CGFloat = 36 + Spacing.lg + Spacing.sm

    /// The floating compose button shows for editable content when the inline
    /// compose panel is closed (over both the editor and the preview), and only
    /// while viewing the skill's own SKILL.md.
    private var showsComposeButton: Bool {
        !showingComposePanel && !skill.isReadOnly && isViewingSkillFile
    }

    /// The skill's directory (parent of SKILL.md) for local directory skills.
    private var skillDirectoryURL: URL? {
        guard !skill.isRemote, skill.isDirectory else { return nil }
        return URL(fileURLWithPath: skill.filePath).deletingLastPathComponent()
    }

    /// Show the Files rail only for local directory skills that bundle resources
    /// beyond the single SKILL.md. Single-file and remote skills keep the plain
    /// editor.
    private var showsFileRail: Bool {
        guard skillDirectoryURL != nil else { return false }
        return fileTree.contains { node in
            node.isDirectory || node.name != "SKILL.md"
        }
    }

    /// True when the selection is the skill's own SKILL.md (or nothing yet) — the
    /// case that drives the `Skill`-backed editor, compose, and validation.
    private var isViewingSkillFile: Bool {
        guard let selectedFileURL else { return true }
        return selectedFileURL.standardizedFileURL == URL(fileURLWithPath: skill.filePath).standardizedFileURL
    }

    private var selectedBundledNode: SkillFileNode? {
        guard let selectedFileURL, !isViewingSkillFile else { return nil }
        return Self.findNode(selectedFileURL, in: fileTree)
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                if showsFileRail, let dir = skillDirectoryURL {
                    FilesColumnView(
                        rootURL: dir,
                        selection: $selectedFileURL,
                        isReadOnly: skill.isReadOnly,
                        nodes: fileTree,
                        onChange: refreshTree
                    )
                    .layoutPriority(0)
                }
                editorPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            SkillMetadataBar(skill: skill)
        }
        .navigationTitle(skill.name)
        .onAppear {
            document.load(from: skill)
            refreshTree()
            if selectedFileURL == nil {
                selectedFileURL = URL(fileURLWithPath: skill.filePath)
            }
            if appState.openComposeAfterCreate && !skill.isReadOnly {
                appState.openComposeAfterCreate = false
                showingComposePanel = true
            }
        }
        .onChange(of: skill.filePath) {
            autoSaveTask?.cancel()
            document.load(from: skill)
            selectedFileURL = URL(fileURLWithPath: skill.filePath)
            refreshTree()
        }
        .onChange(of: document.editorContent) {
            guard !skill.isReadOnly else { return }
            autoSaveTask?.cancel()
            autoSaveTask = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, document.hasUnsavedChanges else { return }
                document.save(to: skill)
            }
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveCurrentSkill)) { _ in
            guard !skill.isReadOnly else { return }
            document.save(to: skill)
        }
        .alert("Save Error", isPresented: $document.showingSaveError) {
            Button("OK") {}
        } message: {
            Text(document.saveErrorMessage)
        }
        .toolbar {
            ToolbarItem {
                Picker("Mode", selection: $preferPreview) {
                    Image(systemName: "pencil")
                        .accessibilityLabel("Edit")
                        .tag(false)
                    Image(systemName: "eye")
                        .accessibilityLabel("Preview")
                        .tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Editor mode")
                .accessibilityValue(preferPreview ? "Preview" : "Edit")
            }
            ToolbarItem {
                Button {
                    skill.isFavorite.toggle()
                    try? modelContext.save()
                } label: {
                    Image(systemName: skill.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(skill.isFavorite ? .yellow : .secondary)
                }
                .help(skill.isFavorite ? "Unfavorite" : "Favorite")
                .accessibilityLabel("Favorite")
                .accessibilityValue(skill.isFavorite ? "On" : "Off")
                .accessibilityAddTraits(skill.isFavorite ? .isSelected : [])
            }
            if !skill.isRemote {
                ToolbarItem {
                    Button {
                        NSWorkspace.shared.selectFile(skill.filePath, inFileViewerRootedAtPath: "")
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Show in Finder")
                    .accessibilityLabel("Show in Finder")
                }
            }
            if !skill.isReadOnly {
                ToolbarItem {
                    Button {
                        activeAlert = .confirmDelete
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete \(skill.displayTypeName)")
                    .accessibilityLabel("Delete \(skill.displayTypeName)")
                }
            }
            if skill.canMakeGlobal {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeAlert = .confirmMakeGlobal
                    } label: {
                        Image(systemName: "globe")
                    }
                    .help("Make Global")
                    .accessibilityLabel("Make Global")
                }
            }
        }
        .alert(
            activeAlert.map(alertTitle) ?? "",
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            presenting: activeAlert,
            actions: alertActions,
            message: alertMessage
        )
    }

    // MARK: - Alerts

    private func alertTitle(_ alert: ActiveAlert) -> String {
        switch alert {
        case .confirmMakeGlobal: "Make \"\(skill.name)\" Global?"
        case .confirmDelete: "Delete \(skill.displayTypeName)?"
        case .deleteError: "Delete Failed"
        case .makeGlobalError: "Make Global Failed"
        }
    }

    @ViewBuilder
    private func alertActions(for alert: ActiveAlert) -> some View {
        switch alert {
        case .confirmMakeGlobal:
            Button("Make Global") { makeSkillGlobal() }
            Button("Cancel", role: .cancel) {}
        case .confirmDelete:
            Button("Delete", role: .destructive) { deleteSkill() }
            Button("Cancel", role: .cancel) {}
        case .deleteError, .makeGlobalError:
            Button("OK") {}
        }
    }

    @ViewBuilder
    private func alertMessage(for alert: ActiveAlert) -> some View {
        switch alert {
        case .confirmMakeGlobal:
            Text("This will move the skill to ~/.agents/skills/ and symlink it to all installed agents.")
        case .confirmDelete:
            Text("This will permanently delete \"\(skill.name)\" from disk.")
        case .deleteError(let message), .makeGlobalError(let message):
            Text(message)
        }
    }

    // MARK: - Editor pane

    @ViewBuilder
    private var editorPane: some View {
        @Bindable var document = document

        if let node = selectedBundledNode {
            BundledFileView(node: node, isReadOnly: skill.isReadOnly)
                .frame(minHeight: Sizing.editorMinHeight)
        } else {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    if preferPreview {
                        SkillPreviewView(content: document.editorContent)
                    } else {
                        SkillEditorView(
                            document: document,
                            isEditable: !skill.isReadOnly,
                            bottomContentInset: showsComposeButton ? Self.composeButtonClearance : Spacing.sm
                        )
                    }

                    if showsComposeButton {
                        composeFloatingButton
                            .zIndex(Layering.floatingAction)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: Sizing.editorMinHeight)
                .layoutPriority(1)

                if showingComposePanel {
                    ComposePanel(
                        content: $document.editorContent,
                        isVisible: $showingComposePanel,
                        skillName: skill.name,
                        skillDescription: skill.skillDescription,
                        frontmatter: skill.frontmatter,
                        filePath: skill.filePath,
                        workingDirectory: URL(fileURLWithPath: skill.filePath).deletingLastPathComponent(),
                        templateType: WizardTemplateType(rawValue: skill.itemKind.rawValue) ?? .skill,
                        onAccept: { document.save(to: skill) }
                    )
                    .id(skill.filePath)
                }
            }
        }
    }

    private func refreshTree() {
        guard let dir = skillDirectoryURL else {
            fileTree = []
            return
        }
        fileTree = SkillDirectoryService.enumerate(dir)

        // If the selected file vanished (deleted/renamed elsewhere), fall back to
        // the skill's SKILL.md.
        if let selectedFileURL, !FileManager.default.fileExists(atPath: selectedFileURL.path) {
            self.selectedFileURL = URL(fileURLWithPath: skill.filePath)
        }
    }

    private static func findNode(_ url: URL, in nodes: [SkillFileNode]) -> SkillFileNode? {
        let target = url.standardizedFileURL
        for node in nodes {
            if node.url.standardizedFileURL == target { return node }
            if let children = node.children, let found = findNode(url, in: children) {
                return found
            }
        }
        return nil
    }

    private var composeFloatingButton: some View {
        Button {
            showingComposePanel.toggle()
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: composeButtonSize * 0.39, weight: .semibold))
                .foregroundStyle(Color(nsColor: .alternateSelectedControlTextColor))
                .frame(width: composeButtonSize, height: composeButtonSize)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.25), radius: Radius.sm, y: 2)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .help("Compose with AI")
        .accessibilityLabel("Compose with AI")
        .padding(Spacing.lg)
    }

    private func makeSkillGlobal() {
        do {
            try skill.makeGlobal()
            try? modelContext.save()
        } catch {
            activeAlert = .makeGlobalError(error.localizedDescription)
        }
    }

    private func deleteSkill() {
        guard !skill.isReadOnly else { return }
        do {
            try skill.deleteFromDisk()
            appState.selectedSkill = nil
            modelContext.delete(skill)
            try modelContext.save()
        } catch {
            activeAlert = .deleteError(error.localizedDescription)
        }
    }
}

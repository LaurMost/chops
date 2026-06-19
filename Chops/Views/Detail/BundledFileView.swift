import AppKit
import PDFKit
import SwiftUI

/// Filesystem-backed text document for non-`SKILL.md` bundled files. Unlike
/// `SkillEditorDocument` it is not tied to a `Skill` / SwiftData record; it just
/// reads and writes a file on disk with debounced autosave.
@MainActor
@Observable
final class FileEditorDocument {
    var editorContent: String = "" {
        didSet {
            guard !isLoading else { return }
            hasUnsavedChanges = editorContent != savedContent
        }
    }

    var hasUnsavedChanges = false
    private(set) var url: URL?
    private var savedContent = ""
    private var isLoading = false

    func load(_ url: URL) {
        flush()
        isLoading = true
        self.url = url
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        editorContent = content
        savedContent = content
        hasUnsavedChanges = false
        isLoading = false
    }

    /// Persist pending changes for the currently loaded file, if any.
    func flush() {
        guard let url, hasUnsavedChanges else { return }
        do {
            try editorContent.write(to: url, atomically: true, encoding: .utf8)
            savedContent = editorContent
            hasUnsavedChanges = false
            AppLogger.fileIO.info("Saved bundled file: \(url.path)")
        } catch {
            AppLogger.fileIO.error("Failed to save bundled file: \(error.localizedDescription)")
        }
    }
}

/// Right-hand detail view for a selected bundled file. Switches on the file kind:
/// text → editor, image/pdf → preview, other binary → open/reveal actions.
struct BundledFileView: View {
    let node: SkillFileNode
    let isReadOnly: Bool

    @State private var document = FileEditorDocument()
    @State private var autoSaveTask: Task<Void, Never>?

    var body: some View {
        @Bindable var document = document
        return Group {
            switch node.kind {
            case .text:
                HighlightedTextEditor(text: $document.editorContent, isEditable: !isReadOnly)
                    .onAppear { document.load(node.url) }
                    .onChange(of: node.url) {
                        autoSaveTask?.cancel()
                        document.load(node.url)
                    }
                    .onChange(of: document.editorContent) {
                        guard !isReadOnly else { return }
                        autoSaveTask?.cancel()
                        autoSaveTask = Task {
                            try? await Task.sleep(for: .seconds(1))
                            guard !Task.isCancelled, document.hasUnsavedChanges else { return }
                            document.flush()
                        }
                    }
                    .onDisappear {
                        autoSaveTask?.cancel()
                        document.flush()
                    }
            case .image:
                ImagePreview(url: node.url)
            case .pdf:
                PDFPreview(url: node.url)
            case .otherBinary, .directory:
                binaryActions
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var binaryActions: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(node.name)
                .font(.headline)
            Text("This file can't be previewed.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.md) {
                Button("Open in Default App") {
                    NSWorkspace.shared.open(node.url)
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                }
            }
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

private struct ImagePreview: View {
    let url: URL

    var body: some View {
        Group {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.lg)
            } else {
                ContentUnavailableView("Can't load image", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context _: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}

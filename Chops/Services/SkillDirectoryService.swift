import Foundation
import UniformTypeIdentifiers

/// How a bundled file should be presented in the skill detail view.
enum SkillFileKind: Equatable {
    case directory
    case text
    case image
    case pdf
    case otherBinary
}

/// A node in a skill directory's file tree. Directories carry `children`; files
/// have `children == nil`.
struct SkillFileNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let kind: SkillFileKind
    var children: [SkillFileNode]?

    var id: String { url.path }
    var isDirectory: Bool { kind == .directory }

    static func == (lhs: SkillFileNode, rhs: SkillFileNode) -> Bool {
        lhs.url == rhs.url && lhs.kind == rhs.kind && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

/// Enumerates a skill directory into a `SkillFileNode` tree and classifies files
/// for preview/edit. Pure filesystem reads — safe to call on demand when the
/// detail view opens; nothing is persisted.
enum SkillDirectoryService {
    /// Directory/file names that are never surfaced in the browser.
    static let ignoredNames: Set<String> = [".git", "node_modules", ".DS_Store"]

    /// Guards against runaway trees (deep nesting or huge node counts).
    static let maxDepth = 6
    static let maxNodeCount = 2000

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "bmp", "tiff", "tif", "svg", "icns",
    ]

    /// Common text/source extensions. UTType is used as a fallback for anything
    /// not listed here.
    static let textExtensions: Set<String> = [
        "md", "mdc", "markdown", "txt", "text", "rtf", "log",
        "json", "yaml", "yml", "toml", "xml", "plist", "csv", "tsv",
        "ini", "cfg", "conf", "env", "properties", "gitignore", "dockerignore",
        "py", "js", "jsx", "ts", "tsx", "mjs", "cjs", "rb", "go", "rs", "swift",
        "c", "h", "cpp", "cc", "hpp", "m", "mm", "java", "kt", "kts", "scala",
        "php", "pl", "pm", "lua", "r", "jl", "dart", "ex", "exs", "erl", "clj",
        "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd",
        "sql", "graphql", "gql", "html", "htm", "css", "scss", "sass", "less",
        "vue", "svelte", "rules", "gradle", "make", "mk", "cmake", "tf",
    ]

    /// Extension-less filenames that are conventionally plain text.
    static let knownTextFilenames: Set<String> = [
        "makefile", "dockerfile", "readme", "license", "licence", "notice",
        "changelog", "authors", "contributors", "codeowners", "procfile",
    ]

    static func shouldIgnore(_ name: String) -> Bool {
        ignoredNames.contains(name) || name.hasPrefix(".DS_Store")
    }

    /// Classify a file (not a directory) by its name. Does not touch the disk,
    /// so it is safe for both enumeration and unit testing.
    static func classify(fileNamed name: String) -> SkillFileKind {
        let ext = (name as NSString).pathExtension.lowercased()

        if !ext.isEmpty {
            if imageExtensions.contains(ext) { return .image }
            if ext == "pdf" { return .pdf }
            if textExtensions.contains(ext) { return .text }

            if let type = UTType(filenameExtension: ext) {
                if type.conforms(to: .image) { return .image }
                if type.conforms(to: .pdf) { return .pdf }
                if type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .script) {
                    return .text
                }
            }
            return .otherBinary
        }

        if knownTextFilenames.contains(name.lowercased()) { return .text }
        return .otherBinary
    }

    /// Build the file tree for a skill directory. `root` should be the skill's
    /// directory (the parent of `SKILL.md`).
    static func enumerate(_ root: URL) -> [SkillFileNode] {
        var count = 0
        return children(of: root, depth: 0, count: &count)
    }

    private static func children(of directory: URL, depth: Int, count: inout Int) -> [SkillFileNode] {
        guard depth < maxDepth, count < maxNodeCount else { return [] }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return [] }

        var nodes: [SkillFileNode] = []
        for entry in entries.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            guard count < maxNodeCount else { break }
            let name = entry.lastPathComponent
            guard !shouldIgnore(name) else { continue }

            count += 1
            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)

            if isDir.boolValue {
                let kids = children(of: entry, depth: depth + 1, count: &count)
                nodes.append(SkillFileNode(url: entry, name: name, kind: .directory, children: kids))
            } else {
                nodes.append(SkillFileNode(url: entry, name: name, kind: classify(fileNamed: name), children: nil))
            }
        }

        // Directories first, then files, each alphabetically.
        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

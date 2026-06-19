import SwiftData
import SwiftUI

struct SkillMetadataBar: View {
    @Bindable var skill: Skill
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkillCollection.sortOrder) private var allCollections: [SkillCollection]
    @State private var showingCollectionPicker = false
    @State private var installError: String?
    @State private var showingInstallError = false
    @State private var computedDirectorySize: Int?

    private var validationIssues: [ValidationIssue] { skill.specValidationIssues }

    private var hasSpecInfo: Bool {
        !validationIssues.isEmpty
            || skill.license != nil
            || skill.compatibility != nil
            || skill.allowedTools != nil
            || !skill.metadata.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasSpecInfo {
                specInfoStrip
                Divider()
            }
            mainBar
        }
        .background(.bar)
        .task(id: skill.filePath) {
            computedDirectorySize = await directorySize()
        }
    }

    // MARK: - Spec info strip

    private var specInfoStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(validationIssues) { issue in
                Label(issue.message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if hasOptionalFields {
                HStack(spacing: Spacing.md) {
                    if let license = skill.license { fieldChip("License", license) }
                    if let compatibility = skill.compatibility { fieldChip("Compatibility", compatibility) }
                    if let allowedTools = skill.allowedTools { fieldChip("Allowed tools", allowedTools) }
                    ForEach(metadataPairs, id: \.0) { key, value in
                        fieldChip(key, value)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var hasOptionalFields: Bool {
        skill.license != nil || skill.compatibility != nil || skill.allowedTools != nil || !skill.metadata.isEmpty
    }

    private var metadataPairs: [(String, String)] {
        skill.metadata.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func fieldChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: Radius.sm))
    }

    private var mainBar: some View {
        HStack(spacing: Spacing.md) {
            // Tool icons — clicking shows installed paths
            HStack(spacing: 6) {
                ForEach(skill.toolSources) { tool in
                    ToolIcon(tool: tool, size: 14)
                }
            }
            .help(installedPathsSummary)

            Divider().frame(height: 14)

            if skill.isRemote, let server = skill.remoteServer {
                Label {
                    Text(server.label)
                } icon: {
                    Image(systemName: "server.rack")
                }
                .font(.caption)
                .foregroundStyle(.indigo)

                Divider().frame(height: 14)
            }

            Text(skill.isRemote ? (skill.remotePath ?? "") : displayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(skill.isRemote ? (skill.remotePath ?? "") : installedPathsSummary)

            Text("·")
                .font(.caption)
                .foregroundStyle(.quaternary)

            Text(formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showingCollectionPicker.toggle()
            } label: {
                Image(systemName: "tray")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Assign to collection")
            .accessibilityLabel("Assign to collection")
            .popover(isPresented: $showingCollectionPicker) {
                collectionPickerContent
            }

            if skill.itemKind == .skill && skill.isDirectory && !skill.isReadOnly && !skill.isRemote {
                Divider().frame(height: 14)

                let menuTools: [ToolSource] = ToolSource.allCases.filter {
                    $0.listable && !$0.globalPaths.isEmpty && $0 != .agents
                }

                Menu {
                    ForEach(menuTools) { tool in
                        let isPresent = skill.toolSources.contains(tool)
                        Button {
                            do {
                                if isPresent {
                                    try skill.uninstall(from: tool)
                                } else {
                                    try skill.install(into: tool)
                                }
                                NotificationCenter.default.post(name: .customScanPathsChanged, object: nil)
                            } catch {
                                installError = error.localizedDescription
                                showingInstallError = true
                            }
                        } label: {
                            if isPresent {
                                Label(tool.displayName, systemImage: "checkmark")
                            } else {
                                Text(tool.displayName)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Install to another tool")
                .accessibilityLabel("Install to another tool")
                .alert("Install Error", isPresented: $showingInstallError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(installError ?? "")
                }
            }

            Divider().frame(height: 14)

            Text(skill.fileModifiedDate.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var displayPath: String {
        let additionalCount = max(0, displayInstalledPaths.count - 1)
        let suffix = additionalCount > 0 ? " (+\(additionalCount))" : ""
        return abbreviatedFilePath + suffix
    }

    private var abbreviatedFilePath: String {
        skill.filePath.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(computedDirectorySize ?? skill.fileSize), countStyle: .file)
    }

    /// Total on-disk size of a directory-backed skill (SKILL.md plus all bundled
    /// resources), computed off the main thread. Single-file and remote skills
    /// fall back to the stored `fileSize`.
    private func directorySize() async -> Int {
        guard !skill.isRemote, skill.isDirectory else { return skill.fileSize }
        let directory = URL(fileURLWithPath: skill.filePath).deletingLastPathComponent()
        return await Task.detached {
            let fm = FileManager.default
            var total = 0
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
            ) else { return 0 }
            for case let url as URL in enumerator {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if values?.isRegularFile == true {
                    total += values?.fileSize ?? 0
                }
            }
            return total
        }.value
    }

    private var installedPathsSummary: String {
        displayInstalledPaths
            .map { $0.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~") }
            .joined(separator: "\n")
    }

    private var displayInstalledPaths: [String] {
        let otherPaths = skill.installedPaths
            .filter { $0 != skill.filePath }
            .sorted()
        return [skill.filePath] + otherPaths
    }

    private var collectionPickerContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Collections")
                .font(.headline)
                .padding(.bottom, 6)
            ForEach(allCollections) { collection in
                let isAssigned = skill.collections.contains(where: { $0.name == collection.name })
                Button {
                    if isAssigned {
                        skill.collections.removeAll { $0.name == collection.name }
                    } else {
                        skill.collections.append(collection)
                    }
                    try? modelContext.save()
                } label: {
                    HStack {
                        Image(systemName: collection.icon)
                        Text(collection.name)
                        Spacer()
                        if isAssigned {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .accessibilityValue(isAssigned ? "Assigned" : "Not assigned")
                .accessibilityAddTraits(isAssigned ? .isSelected : [])
            }
            if allCollections.isEmpty {
                Text("No collections yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

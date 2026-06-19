import SwiftData
import SwiftUI

struct SkillMetadataBar: View {
    @Bindable var skill: Skill
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkillCollection.sortOrder) private var allCollections: [SkillCollection]
    @State private var showingCollectionPicker = false
    @State private var installError: String?
    @State private var showingInstallError = false

    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
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
        ByteCountFormatter.string(fromByteCount: Int64(skill.fileSize), countStyle: .file)
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

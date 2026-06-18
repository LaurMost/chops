import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Skill.name) private var allSkills: [Skill]
    @Query(sort: \RemoteServer.label) private var servers: [RemoteServer]
    @State private var syncingServerIDs: Set<String> = []
    @State private var serverErrors: [String: String] = [:]
    @State private var showingErrorForServer: String?

    private var activeSources: [ToolSource] {
        ToolSource.allCases.filter { tool in
            guard tool.listable else { return false }
            return allSkills.contains { !$0.isPlugin && $0.toolSources.contains(tool) }
        }
    }

    private func toolCount(_ tool: ToolSource) -> Int {
        allSkills.count(where: { !$0.isPlugin && $0.toolSources.contains(tool) })
    }

    /// Plugin-capable tools whose toggle is on and that currently yield plugin skills.
    private var pluginTools: [ToolSource] {
        ChopsSettings.pluginCapableTools.filter { tool in
            ChopsSettings.includePlugins(for: tool) && pluginCount(tool) > 0
        }
    }

    private func pluginCount(_ tool: ToolSource) -> Int {
        allSkills.count(where: { skill in
            skill.isPlugin && skill.toolSources.contains(where: tool.pluginGroupSources.contains)
        })
    }

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.sidebarFilter) {
            Section("Library") {
                Label("Skills", systemImage: "doc.text")
                    .badge(allSkills.count(where: { !$0.isPlugin && $0.itemKind == .skill }))
                    .tag(SidebarFilter.allSkills)

                Label("Agents", systemImage: "person.crop.rectangle")
                    .badge(allSkills.count(where: { !$0.isPlugin && $0.itemKind == .agent }))
                    .tag(SidebarFilter.allAgents)

                Label("Rules", systemImage: "list.bullet.rectangle")
                    .badge(allSkills.count(where: { !$0.isPlugin && $0.itemKind == .rule }))
                    .tag(SidebarFilter.allRules)

                Label("Favorites", systemImage: "star")
                    .badge(allSkills.filter(\.isFavorite).count)
                    .tag(SidebarFilter.favorites)
            }

            Section("Tools") {
                ForEach(activeSources) { tool in
                    Label {
                        Text(tool.displayName)
                    } icon: {
                        ToolIcon(tool: tool)
                    }
                    .badge(toolCount(tool))
                    .tag(SidebarFilter.tool(tool))
                }
            }

            if !pluginTools.isEmpty {
                Section("Plugins") {
                    ForEach(pluginTools) { tool in
                        Label {
                            Text(tool.displayName)
                        } icon: {
                            ToolIcon(tool: tool)
                        }
                        .badge(pluginCount(tool))
                        .tag(SidebarFilter.plugins(tool))
                    }
                }
            }

            if !servers.isEmpty {
                Section("Servers") {
                    ForEach(servers) { server in
                        HStack {
                            Label {
                                Text(server.label)
                            } icon: {
                                Image(systemName: "server.rack")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let error = serverErrors[server.id] {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .popover(isPresented: Binding(
                                        get: { showingErrorForServer == server.id },
                                        set: { if !$0 { showingErrorForServer = nil } }
                                    )) {
                                        Text(error)
                                            .font(.caption)
                                            .padding()
                                            .frame(maxWidth: 250)
                                    }
                                    .onTapGesture {
                                        showingErrorForServer = server.id
                                    }
                            }

                            Button {
                                syncServer(server)
                            } label: {
                                if syncingServerIDs.contains(server.id) {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Sync skills from server")
                            .disabled(syncingServerIDs.contains(server.id))
                        }
                        .badge(server.skills.count)
                        .tag(SidebarFilter.server(server.id))
                    }
                }
            }

            Section("Collections") {
                CollectionListView()
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Chops")
    }

    private func syncServer(_ server: RemoteServer) {
        syncingServerIDs.insert(server.id)
        serverErrors.removeValue(forKey: server.id)
        let context = modelContext
        Task {
            let scanner = SkillScanner(modelContext: context)
            await scanner.scanRemoteServer(server)
            syncingServerIDs.remove(server.id)
            if let error = server.lastSyncError {
                serverErrors[server.id] = error
            }
        }
    }
}

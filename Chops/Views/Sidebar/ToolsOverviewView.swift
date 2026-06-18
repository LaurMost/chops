import SwiftData
import SwiftUI

struct ToolsOverviewView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Skill.name) private var allSkills: [Skill]

    private var listableTools: [ToolSource] {
        ToolSource.allCases.filter(\.listable)
    }

    private func skillCount(for tool: ToolSource) -> Int {
        allSkills.count { !$0.isPlugin && $0.toolSources.contains(tool) }
    }

    private func pluginCount(for tool: ToolSource) -> Int {
        allSkills.count { skill in
            skill.isPlugin && skill.toolSources.contains(where: tool.pluginGroupSources.contains)
        }
    }

    var body: some View {
        List {
            ForEach(listableTools) { tool in
                ToolOverviewRow(
                    tool: tool,
                    skillCount: skillCount(for: tool),
                    pluginCount: pluginCount(for: tool),
                    onSelect: {
                        appState.sidebarFilter = .tool(tool)
                    }
                )
            }
        }
        .navigationTitle("All Tools")
    }
}

private struct ToolOverviewRow: View {
    let tool: ToolSource
    let skillCount: Int
    let pluginCount: Int
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ToolIcon(tool: tool, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.displayName)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if skillCount > 0 {
                        Text("\(skillCount) skill\(skillCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if pluginCount > 0 {
                        Text("\(pluginCount) plugin\(pluginCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if skillCount == 0, pluginCount == 0 {
                        Text("No skills")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if tool.isInstalled {
                if skillCount > 0 {
                    Button("View") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text("Installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                if let url = tool.installURL {
                    Link("Set up", destination: url)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

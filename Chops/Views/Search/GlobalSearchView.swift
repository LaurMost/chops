import SwiftData
import SwiftUI

struct GlobalSearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Skill.name) private var allSkills: [Skill]

    @State private var query: String = ""
    @State private var toolFilter: ToolSource?
    @State private var kindFilter: ItemKind?

    private var results: [Skill] {
        var skills = allSkills

        if let tool = toolFilter {
            skills = skills.filter { $0.toolSources.contains(tool) }
        }

        if let kind = kindFilter {
            skills = skills.filter { $0.itemKind == kind }
        }

        guard !query.isEmpty else { return skills }
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
                $0.skillDescription.localizedCaseInsensitiveContains(query) ||
                $0.content.localizedCaseInsensitiveContains(query)
        }
    }

    private var activeTools: [ToolSource] {
        let used = Set(allSkills.flatMap(\.toolSources))
        return ToolSource.allCases.filter { $0.listable && used.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all skills…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        if let first = results.first {
                            navigate(to: first)
                        }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !activeTools.isEmpty || kindFilter != nil {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(
                            label: "All Tools",
                            isActive: toolFilter == nil,
                            action: { toolFilter = nil }
                        )
                        ForEach(activeTools) { tool in
                            FilterChip(
                                label: tool.displayName,
                                isActive: toolFilter == tool,
                                action: { toolFilter = toolFilter == tool ? nil : tool }
                            )
                        }

                        Divider().frame(height: 16)

                        FilterChip(
                            label: "All",
                            isActive: kindFilter == nil,
                            action: { kindFilter = nil }
                        )
                        ForEach(ItemKind.allCases, id: \.self) { kind in
                            FilterChip(
                                label: kind.singularName,
                                isActive: kindFilter == kind,
                                action: { kindFilter = kindFilter == kind ? nil : kind }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            Divider()

            if results.isEmpty {
                VStack {
                    Spacer()
                    Text(query.isEmpty ? "No skills found" : "No results for \"\(query)\"")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 160)
            } else {
                List(results, id: \.resolvedPath) { skill in
                    Button {
                        navigate(to: skill)
                    } label: {
                        SearchResultRow(skill: skill)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 360)
            }
        }
        .frame(width: 560)
        .background(.regularMaterial)
    }

    private func navigate(to skill: Skill) {
        let filter: SidebarFilter
        if skill.isPlugin {
            filter = .plugins(skill.toolSources.first ?? .claude)
        } else if let tool = skill.toolSources.first {
            switch skill.itemKind {
            case .skill: filter = .tool(tool)
            case .agent: filter = .tool(tool)
            case .rule: filter = .tool(tool)
            }
        } else {
            filter = .allSkills
        }
        appState.sidebarFilter = filter
        appState.selectedSkill = skill
        appState.showingGlobalSearch = false
        dismiss()
    }
}

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultRow: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: skill.itemKind.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .lineLimit(1)
                if !skill.skillDescription.isEmpty {
                    Text(skill.skillDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(skill.toolSources.prefix(3), id: \.self) { tool in
                    ToolIcon(tool: tool, size: 12)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

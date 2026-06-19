import SwiftData
import SwiftUI

struct NewSkillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var skillName = ""
    @State private var skillDescription = ""
    @State private var isGlobalScope = true
    @State private var selectedTool: ToolSource = .claude
    @State private var filesystemError: String?

    private var itemKind: ItemKind { appState.newItemKind }

    /// Skills support a global scope (all tools via ~/.agents/skills/);
    /// agents and rules are always tool-specific.
    private var showsScopePicker: Bool { itemKind == .skill }

    private var effectiveTool: ToolSource {
        (showsScopePicker && isGlobalScope) ? .agents : selectedTool
    }

    private var creatableTools: [ToolSource] {
        switch itemKind {
        case .skill:
            return [.amp, .antigravity, .claude, .codex, .cursor, .opencode, .pi]
        case .agent:
            return ToolSource.allCases.filter { !$0.globalAgentPaths.isEmpty }
        case .rule:
            return ToolSource.allCases.filter { !$0.globalRulePaths.isEmpty }
        }
    }

    private var sanitizedID: String {
        skillName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private var filenamePreview: String {
        guard !sanitizedID.isEmpty else { return "" }
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        func abbreviated(_ path: String) -> String {
            path.replacingOccurrences(of: homeDir, with: "~")
        }
        switch itemKind {
        case .skill:
            guard let dir = effectiveTool.globalPaths.first else { return "" }
            return "\(abbreviated(dir))/\(sanitizedID)/SKILL.md"
        case .agent:
            guard let dir = selectedTool.globalAgentPaths.first else { return "" }
            return "\(abbreviated(dir))/\(sanitizedID)/\(sanitizedID).md"
        case .rule:
            guard let dir = selectedTool.globalRulePaths.first else { return "" }
            return "\(abbreviated(dir))/\(sanitizedID).md"
        }
    }

    private var canCreate: Bool {
        !skillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !skillDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !sanitizedID.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $skillName)
                        .textFieldStyle(.plain)
                    if !sanitizedID.isEmpty {
                        Text(filenamePreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField(
                        "What does this \(itemKind.singularName.lowercased()) do? When should it activate?",
                        text: $skillDescription,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .lineLimit(2 ... 4)
                }

                Section {
                    if showsScopePicker {
                        Picker("Scope", selection: $isGlobalScope) {
                            Text("Global — all tools").tag(true)
                            Text("Tool-specific").tag(false)
                        }
                    }
                    if !isGlobalScope || !showsScopePicker {
                        Picker("Tool", selection: $selectedTool) {
                            ForEach(creatableTools) { tool in
                                Label(tool.displayName, systemImage: tool.iconName)
                                    .tag(tool)
                            }
                        }
                    }
                } footer: {
                    if showsScopePicker && isGlobalScope {
                        Text("Installed in ~/.agents/skills/ and symlinked to each of your installed tools. To add a project-local skill, place a file directly in your project's tool directory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New \(itemKind.singularName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createItem() }
                        .disabled(!canCreate)
                }
            }
            .alert("Creation Failed", isPresented: Binding(
                get: { filesystemError != nil },
                set: { if !$0 { filesystemError = nil } }
            )) {
                Button("OK") { filesystemError = nil }
            } message: {
                Text(filesystemError ?? "")
            }
        }
        .frame(minWidth: 400, idealWidth: Sizing.sheetNarrow)
        .onAppear {
            if !creatableTools.contains(selectedTool) {
                selectedTool = creatableTools.first ?? .claude
            }
        }
    }

    private func createItem() {
        let fm = FileManager.default
        guard !sanitizedID.isEmpty else { return }

        let basePath: String
        let fileName: String

        switch itemKind {
        case .agent:
            guard let dir = selectedTool.globalAgentPaths.first else {
                filesystemError = "\(selectedTool.displayName) doesn't support agents"
                return
            }
            basePath = "\(dir)/\(sanitizedID)"
            fileName = "\(sanitizedID).md"
        case .rule:
            guard let dir = selectedTool.globalRulePaths.first else {
                filesystemError = "\(selectedTool.displayName) doesn't support rules"
                return
            }
            basePath = dir
            fileName = "\(sanitizedID).md"
        case .skill:
            guard let dir = effectiveTool.globalPaths.first else {
                filesystemError = "\(effectiveTool.displayName) doesn't support skills"
                return
            }
            basePath = "\(dir)/\(sanitizedID)"
            fileName = "SKILL.md"
        }

        do {
            try fm.createDirectory(atPath: basePath, withIntermediateDirectories: true)

            let filePath = "\(basePath)/\(fileName)"
            var installedPaths = [filePath]
            var toolSources = [effectiveTool]

            guard !fm.fileExists(atPath: filePath) else {
                filesystemError = "A \(itemKind.singularName.lowercased()) named \"\(sanitizedID)\" already exists"
                return
            }

            let boilerplate = generateBoilerplate(name: skillName, skillID: sanitizedID, description: skillDescription, tool: effectiveTool)
            try boilerplate.write(toFile: filePath, atomically: true, encoding: .utf8)

            if itemKind == .skill && effectiveTool == .agents {
                for agent in AgentTarget.installed {
                    let agentDir = "\(agent.expandedSkillsDir)/\(sanitizedID)"
                    guard !fm.fileExists(atPath: agentDir) else { continue }
                    try fm.createDirectory(atPath: agent.expandedSkillsDir, withIntermediateDirectories: true)
                    try fm.createSymbolicLink(atPath: agentDir, withDestinationPath: basePath)
                    installedPaths.append("\(agentDir)/SKILL.md")
                    if let toolSource = ToolSource.allCases.first(where: { $0.globalPaths.contains(agent.expandedSkillsDir) }) {
                        toolSources.append(toolSource)
                    }
                }
            }

            let parsed = FrontmatterParser.parse(boilerplate)
            let skill = Skill(
                filePath: filePath,
                toolSource: effectiveTool,
                isDirectory: itemKind != .rule,
                name: skillName,
                skillDescription: parsed.description,
                content: parsed.content,
                frontmatter: parsed.frontmatter,
                fileModifiedDate: .now,
                fileSize: boilerplate.count,
                isGlobal: true,
                resolvedPath: filePath,
                kind: itemKind
            )
            skill.installedPaths = installedPaths
            skill.toolSources = toolSources
            modelContext.insert(skill)
            try modelContext.save()

            switch itemKind {
            case .skill: appState.sidebarFilter = .allSkills
            case .agent: appState.sidebarFilter = .allAgents
            case .rule: appState.sidebarFilter = .allRules
            }
            appState.selectedSkill = skill
            appState.openComposeAfterCreate = true
            dismiss()
        } catch {
            filesystemError = error.localizedDescription
        }
    }

    private func generateBoilerplate(name: String, skillID: String, description: String, tool: ToolSource) -> String {
        switch itemKind {
        case .agent:
            return """
            ---
            name: \(skillID)
            description: \(description)
            ---

            # \(name)

            ## Instructions

            Add your agent instructions here.
            """
        case .rule:
            return """
            # \(name)

            Add your rule content here.
            """
        case .skill:
            switch tool {
            case .claude, .cursor, .agents:
                return """
                ---
                name: \(skillID)
                description: \(description)
                ---

                # \(name)

                ## When to Use

                - Describe when this skill should be activated

                ## Instructions

                Add your skill instructions here.
                """
            default:
                return """
                ---
                name: \(skillID)
                description: \(description)
                ---

                # \(name)

                ## Instructions

                Add your skill instructions here.
                """
            }
        }
    }
}

import SwiftData
import SwiftUI
import Yams

struct NewSkillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    private struct MetadataRow: Identifiable {
        let id = UUID()
        var key = ""
        var value = ""
    }

    @State private var skillName = ""
    @State private var skillDescription = ""
    @State private var isGlobalScope = true
    @State private var selectedTool: ToolSource = .claude
    @State private var filesystemError: String?

    // Advanced metadata (skills only).
    @State private var license = ""
    @State private var compatibility = ""
    @State private var allowedTools = ""
    @State private var metadataRows: [MetadataRow] = []
    @State private var scaffoldDirectories = false

    private var itemKind: ItemKind { appState.newItemKind }

    private var showsAdvancedMetadata: Bool { itemKind == .skill }

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

    /// Produces a spec-valid identifier: lowercase ASCII alphanumerics with
    /// single hyphens, no leading/trailing/consecutive hyphens, capped at 64.
    /// `My  Skill!!` → `my-skill`.
    private var sanitizedID: String {
        Self.sanitize(skillName)
    }

    static func sanitize(_ raw: String) -> String {
        let mapped = raw.lowercased().map { character -> Character in
            (character.isASCII && (character.isLetter || character.isNumber)) ? character : "-"
        }
        var result = String(mapped)
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if result.count > SkillSpecValidator.maxNameLength {
            result = String(result.prefix(SkillSpecValidator.maxNameLength))
            result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        return result
    }

    private var validationIssues: [ValidationIssue] {
        SkillSpecValidator.validateForAuthoring(
            SkillSpecValidator.Input(
                name: sanitizedID,
                description: skillDescription,
                compatibility: compatibility.isEmpty ? nil : compatibility
            )
        )
    }

    private func issueMessage(for field: String) -> String? {
        validationIssues.first { $0.field == field }?.message
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
        !validationIssues.contains { $0.severity == .error }
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
                    if !skillName.isEmpty, let message = issueMessage(for: "name") {
                        validationLabel(message)
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
                    if !skillDescription.isEmpty, let message = issueMessage(for: "description") {
                        validationLabel(message)
                    }
                }

                if showsAdvancedMetadata {
                    advancedMetadataSection
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

    private func validationLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private var advancedMetadataSection: some View {
        Section {
            DisclosureGroup("Advanced metadata") {
                TextField("License", text: $license, prompt: Text("MIT"))
                TextField("Compatibility", text: $compatibility, prompt: Text("Requires network access"))
                TextField("Allowed tools", text: $allowedTools, prompt: Text("Bash(git:*) Read"))

                if !compatibility.isEmpty, let message = issueMessage(for: "compatibility") {
                    validationLabel(message)
                }

                LabeledContent("Metadata") {
                    Button {
                        metadataRows.append(MetadataRow())
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                ForEach($metadataRows) { $row in
                    HStack(spacing: Spacing.sm) {
                        TextField("key", text: $row.key)
                        TextField("value", text: $row.value)
                        Button {
                            metadataRows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove metadata row")
                    }
                }

                Toggle("Create scripts/, references/, assets/ folders", isOn: $scaffoldDirectories)
            }
        }
    }

    private var metadataDictionary: [String: String] {
        var result: [String: String] = [:]
        for row in metadataRows {
            let key = row.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            result[key] = row.value
        }
        return result
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

            if itemKind == .skill, scaffoldDirectories {
                for subdir in ["scripts", "references", "assets"] {
                    try fm.createDirectory(atPath: "\(basePath)/\(subdir)", withIntermediateDirectories: true)
                }
            }

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
                metadata: parsed.metadata,
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
            let frontmatter = skillFrontmatterYAML(skillID: skillID, description: description)
            switch tool {
            case .claude, .cursor, .agents:
                return """
                \(frontmatter)
                # \(name)

                ## When to Use

                - Describe when this skill should be activated

                ## Instructions

                Add your skill instructions here.
                """
            default:
                return """
                \(frontmatter)
                # \(name)

                ## Instructions

                Add your skill instructions here.
                """
            }
        }
    }

    /// Builds the `---` delimited frontmatter block for a new skill, emitting
    /// only the fields the user filled in. Yams handles quoting/escaping.
    private func skillFrontmatterYAML(skillID: String, description: String) -> String {
        let document = SkillFrontmatterDocument(
            name: skillID,
            description: description,
            license: license.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            compatibility: compatibility.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            allowedTools: allowedTools.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            metadata: metadataDictionary.isEmpty ? nil : metadataDictionary
        )

        let body = (try? YAMLEncoder().encode(document)) ?? "name: \(skillID)\ndescription: \(description)\n"
        return "---\n\(body)---\n"
    }
}

/// Ordered Encodable used to emit a new skill's frontmatter with only the
/// populated fields, in spec field order.
private struct SkillFrontmatterDocument: Encodable {
    var name: String
    var description: String
    var license: String?
    var compatibility: String?
    var allowedTools: String?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case license
        case compatibility
        case allowedTools = "allowed-tools"
        case metadata
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(license, forKey: .license)
        try container.encodeIfPresent(compatibility, forKey: .compatibility)
        try container.encodeIfPresent(allowedTools, forKey: .allowedTools)
        if let metadata, !metadata.isEmpty {
            try container.encode(metadata, forKey: .metadata)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

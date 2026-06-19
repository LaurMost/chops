import SwiftUI

@Observable
final class AppState {
    var selectedTool: ToolSource?
    var selectedSkill: Skill?
    var searchText: String = ""
    var showingNewSkillSheet: Bool = false
    var showingRegistrySheet: Bool = false
    var showingGlobalSearch: Bool = false
    var newItemKind: ItemKind = .skill
    var sidebarFilter: SidebarFilter = .allSkills
    /// Filter by item kind within a tool view (nil = show all)
    var toolKindFilter: ItemKind?
    /// Set to true by NewSkillSheet after creating a skill; consumed once by SkillDetailView to auto-open compose.
    var openComposeAfterCreate = false
}

enum SidebarFilter: Hashable {
    case allSkills
    case allAgents
    case allRules
    case favorites
    case toolsOverview
    case tool(ToolSource)
    case plugins(ToolSource)
    case collection(String)
    case server(String)
}

import Foundation

/// User-configurable source-of-truth root directory.
/// Sub-directories for skills, agents, and rules are derived from the root.
struct ChopsSettings {
    private init() {}

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    static var sotDir: String {
        get { UserDefaults.standard.string(forKey: "sotDir") ?? "\(home)/.chops" }
        set { UserDefaults.standard.set(newValue, forKey: "sotDir") }
    }

    static var sotSkillsDir: String { "\(sotDir)/skills" }
    static var sotAgentsDir: String { "\(sotDir)/agents" }
    static var sotRulesDir: String { "\(sotDir)/rules" }

    /// Tools whose plugin caches Chops knows how to scan. The Claude toggle also
    /// governs Claude Desktop/Cowork plugin skills.
    static let pluginCapableTools: [ToolSource] = [.claude, .cursor, .codex]

    /// UserDefaults key backing a single tool's plugin toggle.
    static func pluginDefaultsKey(for tool: ToolSource) -> String {
        "includePlugins.\(tool.rawValue)"
    }

    /// Whether plugin skills for a given tool should be scanned. Off by default.
    static func includePlugins(for tool: ToolSource) -> Bool {
        UserDefaults.standard.bool(forKey: pluginDefaultsKey(for: tool))
    }

    /// The set of tools with plugin scanning currently enabled.
    static var enabledPluginTools: Set<ToolSource> {
        Set(pluginCapableTools.filter { includePlugins(for: $0) })
    }
}

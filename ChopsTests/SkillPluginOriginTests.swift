import XCTest
@testable import Chops

final class SkillPluginOriginTests: XCTestCase {

    private func makeSkill(resolvedPath: String, toolSource: ToolSource = .claude) -> Skill {
        Skill(filePath: "/tmp/skill/SKILL.md", toolSource: toolSource, resolvedPath: resolvedPath)
    }

    // MARK: - pluginPackage / pluginPublisher across synthetic schemes

    func testClaudePluginIdentity() {
        let skill = makeSkill(resolvedPath: "claude-plugin:karpathy-skills/andrej-karpathy-skills/karpathy-guidelines")
        XCTAssertEqual(skill.pluginPublisher, "karpathy-skills")
        XCTAssertEqual(skill.pluginPackage, "andrej-karpathy-skills")
    }

    func testCursorPluginIdentity() {
        let skill = makeSkill(resolvedPath: "cursor-plugin:acme/toolbox/refactor", toolSource: .cursor)
        XCTAssertEqual(skill.pluginPublisher, "acme")
        XCTAssertEqual(skill.pluginPackage, "toolbox")
    }

    func testCodexPluginIdentity() {
        let skill = makeSkill(resolvedPath: "codex-plugin:openai-curated/everything-codex/review", toolSource: .codex)
        XCTAssertEqual(skill.pluginPublisher, "openai-curated")
        XCTAssertEqual(skill.pluginPackage, "everything-codex")
    }

    func testClaudeDesktopLocalCoworkIdentity() {
        let skill = makeSkill(
            resolvedPath: "claude-desktop:cowork_plugins/anthropic-marketplace/data-tools/analyze",
            toolSource: .claudeDesktop
        )
        XCTAssertEqual(skill.pluginPublisher, "anthropic-marketplace")
        XCTAssertEqual(skill.pluginPackage, "data-tools")
    }

    func testClaudeDesktopRemoteCoworkHasPackageButNoPublisher() {
        // Remote cowork plugins have no enclosing publisher; the plugin id is the package.
        let skill = makeSkill(
            resolvedPath: "claude-desktop:remote_cowork_plugins/some-remote-plugin/translate",
            toolSource: .claudeDesktop
        )
        XCTAssertNil(skill.pluginPublisher)
        XCTAssertEqual(skill.pluginPackage, "some-remote-plugin")
    }

    // MARK: - Non-plugin skills

    func testFilesystemSkillHasNoPluginIdentity() {
        let skill = makeSkill(resolvedPath: "/Users/me/.claude/skills/my-skill/SKILL.md")
        XCTAssertNil(skill.pluginPublisher)
        XCTAssertNil(skill.pluginPackage)
    }

    func testUnknownSchemeHasNoPluginIdentity() {
        let skill = makeSkill(resolvedPath: "remote://server/path")
        XCTAssertNil(skill.pluginPublisher)
        XCTAssertNil(skill.pluginPackage)
    }

    // MARK: - ToolSource.pluginGroupSources

    func testClaudeGroupSourcesIncludeClaudeDesktop() {
        XCTAssertEqual(ToolSource.claude.pluginGroupSources, [.claude, .claudeDesktop])
    }

    func testCursorAndCodexGroupSourcesAreSelfOnly() {
        XCTAssertEqual(ToolSource.cursor.pluginGroupSources, [.cursor])
        XCTAssertEqual(ToolSource.codex.pluginGroupSources, [.codex])
    }

    func testOtherToolGroupSourcesAreSelfOnly() {
        XCTAssertEqual(ToolSource.amp.pluginGroupSources, [.amp])
        XCTAssertEqual(ToolSource.agents.pluginGroupSources, [.agents])
    }
}

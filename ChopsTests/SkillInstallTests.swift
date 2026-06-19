import XCTest
@testable import Chops

final class SkillInstallableToolsTests: XCTestCase {
    private func makeSkill(toolSources: [ToolSource]) -> Skill {
        let skill = Skill(filePath: "/tmp/skill/SKILL.md", toolSource: toolSources.first ?? .custom, resolvedPath: "/tmp/skill/SKILL.md")
        if toolSources.count > 1 {
            for tool in toolSources.dropFirst() {
                skill.addInstallation(path: "/tmp/\(tool.rawValue)/skill/SKILL.md", tool: tool)
            }
        }
        return skill
    }

    func testInstallableToolsExcludesCurrentToolSources() {
        let skill = makeSkill(toolSources: [.claude])
        let installable = skill.installableTools
        XCTAssertFalse(installable.contains(.claude))
    }

    func testInstallableToolsOnlyIncludesListableToolsWithGlobalPaths() {
        let skill = makeSkill(toolSources: [.claude])
        let installable = skill.installableTools
        for tool in installable {
            XCTAssertTrue(tool.listable, "\(tool) is not listable")
            XCTAssertFalse(tool.globalPaths.isEmpty, "\(tool) has no globalPaths")
        }
    }

    func testInstallableToolsExcludesNonListableTools() {
        let skill = makeSkill(toolSources: [])
        let installable = skill.installableTools
        XCTAssertFalse(installable.contains(.custom))
        XCTAssertFalse(installable.contains(.claudeDesktop))
        XCTAssertFalse(installable.contains(.aider))
    }

    func testInstallableToolsExcludesToolsWithNoGlobalPaths() {
        let skill = makeSkill(toolSources: [])
        let installable = skill.installableTools
        // windsurf has empty globalPaths
        XCTAssertFalse(installable.contains(.windsurf))
    }

    func testInstallableToolsEmptyWhenAllListableToolsAlreadyInstalled() {
        // Get all listable tools with globalPaths
        let allInstallable = ToolSource.allCases.filter { $0.listable && !$0.globalPaths.isEmpty }
        let skill = makeSkill(toolSources: allInstallable)
        XCTAssertTrue(skill.installableTools.isEmpty)
    }
}

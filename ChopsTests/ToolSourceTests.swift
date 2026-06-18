import XCTest
@testable import Chops

final class ToolSourceTests: XCTestCase {

    // MARK: - Identity

    func testIdEqualsRawValue() {
        for tool in ToolSource.allCases {
            XCTAssertEqual(tool.id, tool.rawValue, "id should equal rawValue for \(tool)")
        }
    }

    func testAllCasesCount() {
        XCTAssertEqual(ToolSource.allCases.count, 16)
    }

    // MARK: - displayName

    func testAllCasesHaveNonEmptyDisplayName() {
        for tool in ToolSource.allCases {
            XCTAssertFalse(tool.displayName.isEmpty, "\(tool) has an empty displayName")
        }
    }

    func testKnownDisplayNames() {
        XCTAssertEqual(ToolSource.claude.displayName, "Claude Code")
        XCTAssertEqual(ToolSource.cursor.displayName, "Cursor")
        XCTAssertEqual(ToolSource.codex.displayName, "Codex")
        XCTAssertEqual(ToolSource.windsurf.displayName, "Windsurf")
        XCTAssertEqual(ToolSource.copilot.displayName, "Copilot")
        XCTAssertEqual(ToolSource.amp.displayName, "Amp")
        XCTAssertEqual(ToolSource.agents.displayName, "Global")
        XCTAssertEqual(ToolSource.custom.displayName, "Custom")
        XCTAssertEqual(ToolSource.claudeDesktop.displayName, "Claude Desktop")
        XCTAssertEqual(ToolSource.augment.displayName, "Auggie")
    }

    // MARK: - iconName

    func testAllCasesHaveNonEmptyIconName() {
        for tool in ToolSource.allCases {
            XCTAssertFalse(tool.iconName.isEmpty, "\(tool) has an empty iconName")
        }
    }

    func testKnownIconNames() {
        XCTAssertEqual(ToolSource.claude.iconName, "brain.head.profile")
        XCTAssertEqual(ToolSource.cursor.iconName, "cursorarrow.rays")
        XCTAssertEqual(ToolSource.codex.iconName, "book.closed")
        XCTAssertEqual(ToolSource.agents.iconName, "globe")
        XCTAssertEqual(ToolSource.custom.iconName, "folder")
        XCTAssertEqual(ToolSource.amp.iconName, "bolt.fill")
    }

    // MARK: - listable

    func testListableIsFalseForNonListableTools() {
        XCTAssertFalse(ToolSource.custom.listable)
        XCTAssertFalse(ToolSource.claudeDesktop.listable)
        XCTAssertFalse(ToolSource.aider.listable)
    }

    func testListableIsTrueForCommonTools() {
        XCTAssertTrue(ToolSource.claude.listable)
        XCTAssertTrue(ToolSource.cursor.listable)
        XCTAssertTrue(ToolSource.codex.listable)
        XCTAssertTrue(ToolSource.windsurf.listable)
        XCTAssertTrue(ToolSource.copilot.listable)
        XCTAssertTrue(ToolSource.amp.listable)
        XCTAssertTrue(ToolSource.agents.listable)
    }

    // MARK: - globalPaths

    func testGlobalPathsContainHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let tools: [ToolSource] = [.claude, .cursor, .codex, .copilot, .amp, .agents]
        for tool in tools {
            let paths = tool.globalPaths
            XCTAssertFalse(paths.isEmpty, "\(tool) should have at least one global path")
            for path in paths {
                XCTAssertTrue(path.hasPrefix(home) || path.hasPrefix("/opt/homebrew") || path.hasPrefix("/usr/local"),
                              "\(tool) path '\(path)' doesn't start with home or well-known prefix")
            }
        }
    }

    func testGlobalPathsEmptyForCustomAndClaudeDesktop() {
        XCTAssertTrue(ToolSource.custom.globalPaths.isEmpty)
        XCTAssertTrue(ToolSource.claudeDesktop.globalPaths.isEmpty)
    }

    // MARK: - globalRulePaths

    func testCursorHasGlobalRulePaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = ToolSource.cursor.globalRulePaths
        XCTAssertFalse(paths.isEmpty)
        XCTAssertTrue(paths.contains("\(home)/.cursor/rules"))
    }

    func testCodexHasGlobalRulePaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = ToolSource.codex.globalRulePaths
        XCTAssertFalse(paths.isEmpty)
        XCTAssertTrue(paths.contains("\(home)/.codex/rules"))
    }

    func testClaudeHasNoGlobalRulePaths() {
        XCTAssertTrue(ToolSource.claude.globalRulePaths.isEmpty)
    }

    // MARK: - globalAgentPaths

    func testClaudeGlobalAgentPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(ToolSource.claude.globalAgentPaths.contains("\(home)/.claude/agents"))
    }

    func testCustomHasNoGlobalAgentPaths() {
        XCTAssertTrue(ToolSource.custom.globalAgentPaths.isEmpty)
    }

    // MARK: - logoAssetName

    func testLogoAssetNameForKnownTools() {
        XCTAssertEqual(ToolSource.claude.logoAssetName, "tool-claude")
        XCTAssertEqual(ToolSource.cursor.logoAssetName, "tool-cursor")
        XCTAssertEqual(ToolSource.codex.logoAssetName, "tool-codex")
        XCTAssertEqual(ToolSource.claudeDesktop.logoAssetName, "tool-claude")
    }

    func testLogoAssetNameIsNilForToolsWithoutCustomLogo() {
        XCTAssertNil(ToolSource.aider.logoAssetName)
        XCTAssertNil(ToolSource.hermes.logoAssetName)
        XCTAssertNil(ToolSource.pi.logoAssetName)
        XCTAssertNil(ToolSource.agents.logoAssetName)
        XCTAssertNil(ToolSource.custom.logoAssetName)
    }

    // MARK: - Codable round-trip

    func testRawValueRoundTrip() throws {
        for tool in ToolSource.allCases {
            let encoded = try JSONEncoder().encode(tool)
            let decoded = try JSONDecoder().decode(ToolSource.self, from: encoded)
            XCTAssertEqual(decoded, tool, "Round-trip failed for \(tool)")
        }
    }
}

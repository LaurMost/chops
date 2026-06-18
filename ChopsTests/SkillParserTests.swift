import XCTest
@testable import Chops

final class SkillParserTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChopsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    private func writeFile(named name: String, content: String) -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Frontmatter format (.md)

    func testParseFrontmatterMd() {
        let content = """
        ---
        name: My Claude Skill
        description: A helpful skill
        ---
        Skill body text.
        """
        let url = writeFile(named: "skill.md", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .claude)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "My Claude Skill")
        XCTAssertEqual(parsed?.description, "A helpful skill")
        XCTAssertEqual(parsed?.content, "Skill body text.")
    }

    func testParseMdcExtension() {
        let content = """
        ---
        name: Cursor Rule
        description: Auto-applies to TypeScript
        ---
        Always use strict TypeScript.
        """
        let url = writeFile(named: "rule.mdc", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .cursor)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "Cursor Rule")
        XCTAssertEqual(parsed?.description, "Auto-applies to TypeScript")
    }

    func testParseHeadingFormatForCodexSource() {
        let content = """
        # My Codex Skill

        This skill helps with something useful.
        """
        let url = writeFile(named: "codex-skill.md", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .codex)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "My Codex Skill")
    }

    func testParseHeadingFormatTakesFirstHeading() {
        let content = """
        # First Heading

        ## Second Heading

        Content body.
        """
        let url = writeFile(named: "multi-heading.md", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .amp)
        XCTAssertEqual(parsed?.name, "First Heading")
    }

    func testFrontmatterTakesPriorityOverHeadingForCodexSource() {
        let content = """
        ---
        name: Frontmatter Name
        ---
        # Heading Name

        Body.
        """
        let url = writeFile(named: "both.md", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .codex)
        XCTAssertEqual(parsed?.name, "Frontmatter Name")
    }

    func testNoNameInHeadingFormatReturnsEmptyName() {
        let content = "Just a paragraph, no heading."
        let url = writeFile(named: "no-heading.md", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .agents)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.name, "")
    }

    func testFileNotFoundReturnsNil() {
        let url = tempDir.appendingPathComponent("does-not-exist.md")
        let parsed = SkillParser.parse(fileURL: url, toolSource: .claude)
        XCTAssertNil(parsed)
    }

    func testCursorMdFileUsesFrontmatterParser() {
        let content = """
        ---
        name: Cursor Skill MD
        ---
        Content
        """
        let url = writeFile(named: "cursor-skill.md", content: content)
        let parsed = SkillParser.parse(fileURL: url, toolSource: .cursor)
        XCTAssertEqual(parsed?.name, "Cursor Skill MD")
    }
}

import XCTest
@testable import Chops

final class FrontmatterParserTests: XCTestCase {
    // MARK: - No frontmatter

    func testEmptyString() {
        let result = FrontmatterParser.parse("")
        XCTAssertEqual(result.frontmatter, [:])
        XCTAssertEqual(result.content, "")
        XCTAssertEqual(result.name, "")
        XCTAssertEqual(result.description, "")
    }

    func testPlainTextNoPreamble() {
        let text = "This is just plain text.\nNo frontmatter here."
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter, [:])
        XCTAssertEqual(result.content, text)
        XCTAssertEqual(result.name, "")
    }

    func testUnclosedFrontmatter() {
        let text = "---\nname: My Skill\ndescription: No closing delimiter"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter, [:])
        XCTAssertEqual(result.content, text)
    }

    func testLeadingWhitespaceOnDashLineStillTriggersFrontmatter() {
        // The parser trims whitespace before comparing, so "  ---" is treated as "---"
        let text = "  ---\nname: My Skill\n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "My Skill")
        XCTAssertEqual(result.content, "Content")
    }

    // MARK: - Valid frontmatter

    func testEmptyFrontmatterBlock() {
        let text = "---\n---\nSome content here"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter, [:])
        XCTAssertEqual(result.content, "Some content here")
        XCTAssertEqual(result.name, "")
    }

    func testSingleKeyValue() {
        let text = "---\nname: My Skill\n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "My Skill")
        XCTAssertEqual(result.name, "My Skill")
        XCTAssertEqual(result.content, "Content")
    }

    func testNameAndDescription() {
        let text = "---\nname: Test Skill\ndescription: Does something useful\n---\nBody text"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.name, "Test Skill")
        XCTAssertEqual(result.description, "Does something useful")
        XCTAssertEqual(result.content, "Body text")
    }

    func testMultipleKeys() {
        let text = """
        ---
        name: Multi Key
        description: A description
        tags: swift, testing
        author: Alice
        ---
        The actual content.
        """
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "Multi Key")
        XCTAssertEqual(result.frontmatter["description"], "A description")
        XCTAssertEqual(result.frontmatter["tags"], "swift, testing")
        XCTAssertEqual(result.frontmatter["author"], "Alice")
        XCTAssertEqual(result.content, "The actual content.")
    }

    func testValueWithColonInsideIt() {
        let text = "---\nname: My: Skill: With Colons\n---\nContent"
        let result = FrontmatterParser.parse(text)
        // Only the first colon is the key/value separator
        XCTAssertEqual(result.frontmatter["name"], "My: Skill: With Colons")
    }

    func testLeadingWhitespaceStrippedFromKeyAndValue() {
        let text = "---\n  name  :  Spaced Skill  \n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "Spaced Skill")
    }

    func testFrontmatterOnlyNoContent() {
        let text = "---\nname: SkillOnly\n---"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.name, "SkillOnly")
        XCTAssertEqual(result.content, "")
    }

    func testContentPreservesMultipleLines() {
        let text = "---\nname: Rich Content\n---\nLine one\nLine two\n\nLine four"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.content, "Line one\nLine two\n\nLine four")
    }

    func testSpecialCharactersInValue() {
        let text = "---\nname: émojis 🎉 & <tags>\n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "émojis 🎉 & <tags>")
    }

    func testEmptyValueForKey() {
        let text = "---\nname:\ndescription: Has description\n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "")
        XCTAssertEqual(result.frontmatter["description"], "Has description")
        XCTAssertEqual(result.name, "")
    }

    func testLineWithoutColonIsIgnored() {
        let text = "---\nname: Valid\nnocolon\n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.frontmatter["name"], "Valid")
        XCTAssertNil(result.frontmatter["nocolon"])
    }

    func testContentIsTrimmedOfLeadingAndTrailingWhitespace() {
        let text = "---\nname: Trim Test\n---\n\n  Content with spaces  \n\n"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.content, "Content with spaces")
    }

    func testNameFallsBackToEmptyWhenKeyMissing() {
        let text = "---\ndescription: Only a description\n---\nContent"
        let result = FrontmatterParser.parse(text)
        XCTAssertEqual(result.name, "")
        XCTAssertEqual(result.description, "Only a description")
    }
}

// MARK: - MDCParser

final class MDCParserTests: XCTestCase {
    func testMDCParserDelegatesToFrontmatterParser() {
        let text = "---\nname: Cursor Rule\ndescription: A cursor rule\n---\nRule content here."
        let mdcResult = MDCParser.parse(text)
        let fmResult = FrontmatterParser.parse(text)
        XCTAssertEqual(mdcResult.name, fmResult.name)
        XCTAssertEqual(mdcResult.description, fmResult.description)
        XCTAssertEqual(mdcResult.content, fmResult.content)
        XCTAssertEqual(mdcResult.frontmatter, fmResult.frontmatter)
    }

    func testMDCParserNoFrontmatter() {
        let text = "Just some rule text without YAML."
        let result = MDCParser.parse(text)
        XCTAssertEqual(result.frontmatter, [:])
        XCTAssertEqual(result.content, text)
    }
}

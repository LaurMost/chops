import XCTest
@testable import Chops

final class OneShotResponseParserTests: XCTestCase {

    // MARK: - Plain text (no code fence)

    func testPlainTextNoFenceReturnsSummaryOnly() {
        let text = "Sure, I added a description to the frontmatter."
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        XCTAssertEqual(result.summary, text)
        XCTAssertNil(result.newContent)
    }

    func testEmptyTextReturnsSummaryOnly() {
        let result = OneShotResponseParser.parse("", originalContent: nil)
        XCTAssertEqual(result.summary, "")
        XCTAssertNil(result.newContent)
    }

    func testWhitespaceOnlyTextReturnsTrimmedSummaryOnly() {
        let result = OneShotResponseParser.parse("   \n  ", originalContent: nil)
        XCTAssertEqual(result.summary, "")
        XCTAssertNil(result.newContent)
    }

    // MARK: - Summary + fenced full-file block

    func testSummaryWithFencedBlock() {
        let text = """
        Updated the description field.

        ```
        ---
        name: My Skill
        description: Updated description
        ---
        Content here.
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        XCTAssertEqual(result.summary, "Updated the description field.")
        XCTAssertEqual(result.newContent, "---\nname: My Skill\ndescription: Updated description\n---\nContent here.\n")
    }

    func testSummaryWithLanguageHintFence() {
        let text = """
        Added tags to frontmatter.

        ```markdown
        ---
        name: Skill
        tags: foo, bar
        ---
        Body
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        XCTAssertEqual(result.summary, "Added tags to frontmatter.")
        XCTAssertNotNil(result.newContent)
        XCTAssertTrue(result.newContent!.contains("tags: foo, bar"))
    }

    func testFencedBlockWithNoSummary() {
        let text = """
        ```
        Full file content here
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        XCTAssertEqual(result.summary, "")
        XCTAssertEqual(result.newContent, "Full file content here\n")
    }

    func testMissingClosingFenceReturnsEverythingAfterOpen() {
        let text = """
        Summary line.

        ```
        Unclosed block starts here
        """
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        XCTAssertEqual(result.summary, "Summary line.")
        XCTAssertTrue(result.newContent!.contains("Unclosed block starts here"))
    }

    func testNestedCodeBlocksUsesLastClosingFence() {
        // Content contains inner fenced examples; parser must use the LAST closing fence.
        let text = """
        Updated the examples.

        ```
        # Skill with examples

        Use like:

        ```bash
        echo hello
        ```

        That's it.
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        XCTAssertEqual(result.summary, "Updated the examples.")
        // Content should include the inner ```bash block
        XCTAssertTrue(result.newContent!.contains("```bash"))
        XCTAssertTrue(result.newContent!.contains("echo hello"))
    }

    // MARK: - Structured-edits JSON envelope

    func testStructuredEditsEmptyEditsReturnsNoContent() {
        let json = """
        {"summary": "No changes needed.", "edits": []}
        """
        let result = OneShotResponseParser.parse(json, originalContent: "original content")
        XCTAssertEqual(result.summary, "No changes needed.")
        XCTAssertNil(result.newContent)
    }

    func testStructuredEditsWithValidEdit() {
        let original = "Hello world\nThis is a test."
        let json = """
        {"summary": "Changed greeting.", "edits": [{"find": "Hello world", "replace": "Hello Swift"}]}
        """
        let result = OneShotResponseParser.parse(json, originalContent: original)
        XCTAssertEqual(result.summary, "Changed greeting.")
        XCTAssertEqual(result.newContent, "Hello Swift\nThis is a test.")
    }

    func testStructuredEditsMultipleEditsAppliedInOrder() {
        let original = "Line A\nLine B\nLine C"
        let json = """
        {"summary": "Replaced A and C.", "edits": [{"find": "Line A", "replace": "Line X"}, {"find": "Line C", "replace": "Line Z"}]}
        """
        let result = OneShotResponseParser.parse(json, originalContent: original)
        XCTAssertEqual(result.newContent, "Line X\nLine B\nLine Z")
    }

    func testStructuredEditsEditNotFoundReturnsNilContent() {
        let original = "The quick brown fox"
        let json = """
        {"summary": "Tried to replace.", "edits": [{"find": "lazy dog", "replace": "active cat"}]}
        """
        let result = OneShotResponseParser.parse(json, originalContent: original)
        XCTAssertEqual(result.summary, "Tried to replace.")
        XCTAssertNil(result.newContent)
    }

    func testStructuredEditsAmbiguousFindReturnsNilContent() {
        let original = "foo bar foo"
        let json = """
        {"summary": "Replace foo.", "edits": [{"find": "foo", "replace": "baz"}]}
        """
        let result = OneShotResponseParser.parse(json, originalContent: original)
        XCTAssertNil(result.newContent)
    }

    func testStructuredEditsNoOriginalContentReturnsNilContent() {
        let json = """
        {"summary": "Made edits.", "edits": [{"find": "foo", "replace": "bar"}]}
        """
        let result = OneShotResponseParser.parse(json, originalContent: nil)
        XCTAssertEqual(result.summary, "Made edits.")
        XCTAssertNil(result.newContent)
    }

    func testStructuredEditsWrappedInJsonCodeFence() {
        let original = "name: old"
        let text = """
        ```json
        {"summary": "Updated name.", "edits": [{"find": "name: old", "replace": "name: new"}]}
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: original)
        XCTAssertEqual(result.summary, "Updated name.")
        XCTAssertEqual(result.newContent, "name: new")
    }

    func testStructuredEditsWrappedInPlainCodeFence() {
        let original = "hello"
        let text = """
        ```
        {"summary": "Replaced.", "edits": [{"find": "hello", "replace": "world"}]}
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: original)
        XCTAssertEqual(result.summary, "Replaced.")
        XCTAssertEqual(result.newContent, "world")
    }

    func testMalformedJSONFallsBackToFencedParsing() {
        let text = """
        Summary text.

        ```
        {not valid json}
        ```
        """
        let result = OneShotResponseParser.parse(text, originalContent: nil)
        // Should fall back: the stripped inner text is not valid JSON, so it tries the fenced path
        XCTAssertNotNil(result.newContent)
    }
}

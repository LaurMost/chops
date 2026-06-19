import XCTest
@testable import Chops

final class SkillSpecValidatorTests: XCTestCase {
    private func authoring(
        name: String,
        description: String = "A valid description",
        compatibility: String? = nil,
        directoryName: String? = nil
    ) -> [ValidationIssue] {
        SkillSpecValidator.validateForAuthoring(
            SkillSpecValidator.Input(
                name: name,
                description: description,
                compatibility: compatibility,
                directoryName: directoryName
            )
        )
    }

    private func hasIssue(_ issues: [ValidationIssue], field: String) -> Bool {
        issues.contains { $0.field == field }
    }

    // MARK: - Name regex

    func testValidNameHasNoIssues() {
        XCTAssertTrue(authoring(name: "my-skill").isEmpty)
        XCTAssertTrue(authoring(name: "skill1").isEmpty)
        XCTAssertTrue(authoring(name: "a1-b2-c3").isEmpty)
    }

    func testLeadingHyphenIsInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: "-skill"), field: "name"))
    }

    func testTrailingHyphenIsInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: "skill-"), field: "name"))
    }

    func testConsecutiveHyphensAreInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: "my--skill"), field: "name"))
    }

    func testUppercaseIsInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: "MySkill"), field: "name"))
    }

    func testEmptyNameIsInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: ""), field: "name"))
    }

    func testNameOver64IsInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: String(repeating: "a", count: 65)), field: "name"))
    }

    func testNameExactly64IsValid() {
        XCTAssertFalse(hasIssue(authoring(name: String(repeating: "a", count: 64)), field: "name"))
    }

    func testNameMismatchWithDirectoryIsFlagged() {
        XCTAssertTrue(hasIssue(authoring(name: "my-skill", directoryName: "other-dir"), field: "name"))
    }

    func testNameMatchingDirectoryIsClean() {
        XCTAssertFalse(hasIssue(authoring(name: "my-skill", directoryName: "my-skill"), field: "name"))
    }

    // MARK: - Description

    func testEmptyDescriptionIsInvalid() {
        XCTAssertTrue(hasIssue(authoring(name: "my-skill", description: "   "), field: "description"))
    }

    func testDescriptionOver1024IsInvalid() {
        let long = String(repeating: "x", count: 1025)
        XCTAssertTrue(hasIssue(authoring(name: "my-skill", description: long), field: "description"))
    }

    // MARK: - Compatibility

    func testCompatibilityOver500IsInvalid() {
        let long = String(repeating: "x", count: 501)
        XCTAssertTrue(hasIssue(authoring(name: "my-skill", compatibility: long), field: "compatibility"))
    }

    func testCompatibilityWithin500IsClean() {
        XCTAssertFalse(hasIssue(authoring(name: "my-skill", compatibility: "Requires network"), field: "compatibility"))
    }

    // MARK: - Severity

    func testAuthoringIssuesAreErrors() {
        let issues = authoring(name: "Bad--Name")
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.allSatisfy { $0.severity == .error })
    }

    func testDiscoveredIssuesAreWarnings() {
        let issues = SkillSpecValidator.validateDiscovered(
            SkillSpecValidator.Input(name: "Bad--Name", description: "ok")
        )
        XCTAssertFalse(issues.isEmpty)
        XCTAssertTrue(issues.allSatisfy { $0.severity == .warning })
    }

    // MARK: - Authoring sanitizer

    func testSanitizeCollapsesAndTrims() {
        XCTAssertEqual(NewSkillSheet.sanitize("My  Skill!!"), "my-skill")
        XCTAssertEqual(NewSkillSheet.sanitize("  Leading and trailing  "), "leading-and-trailing")
        XCTAssertEqual(NewSkillSheet.sanitize("--weird--name--"), "weird-name")
        XCTAssertEqual(NewSkillSheet.sanitize("Hello"), "hello")
    }

    func testSanitizeCapsAt64() {
        let result = NewSkillSheet.sanitize(String(repeating: "a", count: 100))
        XCTAssertEqual(result.count, 64)
    }

    func testSanitizeProducesSpecValidNames() {
        for raw in ["My  Skill!!", "--weird--name--", "Café Sk" + "ill"] {
            let sanitized = NewSkillSheet.sanitize(raw)
            if !sanitized.isEmpty {
                XCTAssertTrue(
                    SkillSpecValidator.matchesNamePattern(sanitized),
                    "Sanitized name '\(sanitized)' should be spec-valid"
                )
            }
        }
    }
}

import XCTest
@testable import Chops

// MARK: - AgentDataDecoding

final class AgentDataDecodingTests: XCTestCase {
    func testNilDataReturnsNil() {
        XCTAssertNil(AgentDataDecoding.text(from: nil))
    }

    func testEmptyDataReturnsEmptyString() {
        let result = AgentDataDecoding.text(from: Data())
        XCTAssertEqual(result, "")
    }

    func testValidUTF8DataDecodesCorrectly() {
        let expected = "Hello, Swift!"
        let data = expected.data(using: .utf8)!
        XCTAssertEqual(AgentDataDecoding.text(from: data), expected)
    }

    func testUnicodeDataDecodesCorrectly() {
        let expected = "日本語テスト 🎉"
        let data = expected.data(using: .utf8)!
        XCTAssertEqual(AgentDataDecoding.text(from: data), expected)
    }
}

// MARK: - AgentError

final class AgentErrorTests: XCTestCase {
    func testNoSessionDescription() {
        let error = AgentError.noSession
        XCTAssertEqual(error.errorDescription, "No active agent session.")
    }

    func testBinaryNotInstalledDescription() {
        let url = URL(string: "https://example.com")!
        let error = AgentError.binaryNotInstalled(toolName: "claude", installURL: url)
        XCTAssertEqual(error.errorDescription, "claude isn't installed.")
    }

    func testAgentTooOldDescription() {
        let error = AgentError.agentTooOld(toolName: "codex", found: "0.9.0", minimum: "1.0.0")
        XCTAssertEqual(error.errorDescription, "codex v0.9.0 is too old. Update to v1.0.0 or newer.")
    }

    func testLaunchFailedDescription() {
        let error = AgentError.launchFailed("Process crashed at startup")
        XCTAssertEqual(error.errorDescription, "Failed to launch agent: Process crashed at startup")
    }

    func testConnectTimedOutDescription() {
        let error = AgentError.connectTimedOut(stage: "handshake")
        XCTAssertEqual(error.errorDescription, "Connection timed out (handshake).")
    }

    func testProcessExitedDuringConnectDescription() {
        let error = AgentError.processExitedDuringConnect("exit code 1")
        XCTAssertTrue(error.errorDescription?.contains("Agent exited before initializing") == true)
        XCTAssertTrue(error.errorDescription?.contains("exit code 1") == true)
    }
}

// MARK: - OneShotPrompts

final class OneShotPromptsTests: XCTestCase {
    func testDefaultSystemPromptContainsFilename() {
        let prompt = OneShotPrompts.defaultSystemPrompt(filePath: "/some/path/my-skill.md")
        XCTAssertTrue(prompt.contains("my-skill.md"))
    }

    func testDefaultSystemPromptWithNilPathUsesFallback() {
        let prompt = OneShotPrompts.defaultSystemPrompt(filePath: nil)
        XCTAssertTrue(prompt.contains("the file"))
    }

    func testDefaultSystemPromptContainsReplyFormatInstructions() {
        let prompt = OneShotPrompts.defaultSystemPrompt(filePath: nil)
        XCTAssertTrue(prompt.contains("Reply format"))
        XCTAssertTrue(prompt.contains("fenced code block"))
    }

    func testUserMessageWithFileContent() {
        let message = OneShotPrompts.userMessage(
            userRequest: "Add a description",
            filePath: "/path/to/skill.md",
            fileContent: "---\nname: Skill\n---\nContent"
        )
        XCTAssertTrue(message.contains("skill.md"))
        XCTAssertTrue(message.contains("---\nname: Skill\n---\nContent"))
        XCTAssertTrue(message.contains("Add a description"))
        XCTAssertTrue(message.contains("User's request:"))
    }

    func testUserMessageWithNilFileContent() {
        let message = OneShotPrompts.userMessage(
            userRequest: "Some request",
            filePath: nil,
            fileContent: nil
        )
        XCTAssertFalse(message.contains("Current contents"))
        XCTAssertTrue(message.contains("Some request"))
    }

    func testUserMessageEmptyFileContentShowsPlaceholder() {
        let message = OneShotPrompts.userMessage(
            userRequest: "Request",
            filePath: "/path/file.md",
            fileContent: ""
        )
        XCTAssertTrue(message.contains("(empty file)"))
    }

    func testUserMessageStructureOrder() {
        // File content block should appear before the user's request
        let message = OneShotPrompts.userMessage(
            userRequest: "My request",
            filePath: "/p/f.md",
            fileContent: "file contents"
        )
        let fileContentsRange = message.range(of: "file contents")!
        let requestRange = message.range(of: "My request")!
        XCTAssertLessThan(fileContentsRange.lowerBound, requestRange.lowerBound)
    }
}

// MARK: - PermissionResponse

final class PermissionResponseTests: XCTestCase {
    func testChoiceFactory() {
        let response = PermissionResponse.choice("allow_once")
        XCTAssertEqual(response.optionId, "allow_once")
        XCTAssertFalse(response.cancelled)
    }

    func testCancelledFactory() {
        let response = PermissionResponse.cancelled
        XCTAssertNil(response.optionId)
        XCTAssertTrue(response.cancelled)
    }
}

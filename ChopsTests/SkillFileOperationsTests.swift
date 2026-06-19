import XCTest
@testable import Chops

final class SkillFileOperationsTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChopsFileOpsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testNewFileCreatesFile() throws {
        let url = try SkillFileOperations.newFile(named: "notes.txt", in: tempDir, isReadOnly: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testNewFolderCreatesDirectory() throws {
        let url = try SkillFileOperations.newFolder(named: "scripts", in: tempDir, isReadOnly: false)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testNewFileRejectsDuplicate() throws {
        _ = try SkillFileOperations.newFile(named: "dup.txt", in: tempDir, isReadOnly: false)
        XCTAssertThrowsError(try SkillFileOperations.newFile(named: "dup.txt", in: tempDir, isReadOnly: false))
    }

    func testRenameMovesFile() throws {
        let original = try SkillFileOperations.newFile(named: "old.txt", in: tempDir, isReadOnly: false)
        let renamed = try SkillFileOperations.rename(original, to: "new.txt", isReadOnly: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
        XCTAssertEqual(renamed.lastPathComponent, "new.txt")
    }

    func testDeleteRemovesFile() throws {
        let url = try SkillFileOperations.newFile(named: "temp.txt", in: tempDir, isReadOnly: false)
        try SkillFileOperations.delete(url, isReadOnly: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteSkillFileIsBlocked() throws {
        let skillFile = tempDir.appendingPathComponent("SKILL.md")
        try "frontmatter".write(to: skillFile, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try SkillFileOperations.delete(skillFile, isReadOnly: false)) { error in
            XCTAssertEqual(error as? SkillFileOperationError, .cannotDeleteSkillFile)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillFile.path))
    }

    func testRenameSkillFileIsBlocked() throws {
        let skillFile = tempDir.appendingPathComponent("SKILL.md")
        try "frontmatter".write(to: skillFile, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try SkillFileOperations.rename(skillFile, to: "OTHER.md", isReadOnly: false))
    }

    func testReadOnlyBlocksAllMutations() {
        XCTAssertThrowsError(try SkillFileOperations.newFile(named: "x.txt", in: tempDir, isReadOnly: true)) { error in
            XCTAssertEqual(error as? SkillFileOperationError, .readOnly)
        }
        XCTAssertThrowsError(try SkillFileOperations.newFolder(named: "x", in: tempDir, isReadOnly: true))
    }
}

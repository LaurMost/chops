import XCTest
@testable import Chops

final class SkillDirectoryServiceTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChopsDirTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Classification

    func testTextClassification() {
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "extract.py"), .text)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "SKILL.md"), .text)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "config.yaml"), .text)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "notes.txt"), .text)
    }

    func testExtensionlessKnownTextFiles() {
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "Makefile"), .text)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "Dockerfile"), .text)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "LICENSE"), .text)
    }

    func testImageClassification() {
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "diagram.png"), .image)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "photo.jpeg"), .image)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "icon.svg"), .image)
    }

    func testPDFClassification() {
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "manual.pdf"), .pdf)
    }

    func testBinaryClassification() {
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "archive.zip"), .otherBinary)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "data.bin"), .otherBinary)
        XCTAssertEqual(SkillDirectoryService.classify(fileNamed: "mystery"), .otherBinary)
    }

    // MARK: - Ignore rules

    func testShouldIgnore() {
        XCTAssertTrue(SkillDirectoryService.shouldIgnore(".git"))
        XCTAssertTrue(SkillDirectoryService.shouldIgnore("node_modules"))
        XCTAssertTrue(SkillDirectoryService.shouldIgnore(".DS_Store"))
        XCTAssertFalse(SkillDirectoryService.shouldIgnore("scripts"))
        XCTAssertFalse(SkillDirectoryService.shouldIgnore("SKILL.md"))
    }

    // MARK: - Enumeration

    func testEnumerationSkipsIgnoredEntries() throws {
        let fm = FileManager.default
        try "frontmatter".write(to: tempDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try fm.createDirectory(at: tempDir.appendingPathComponent("scripts"), withIntermediateDirectories: true)
        try "print('hi')".write(
            to: tempDir.appendingPathComponent("scripts/run.py"),
            atomically: true,
            encoding: .utf8
        )
        try fm.createDirectory(at: tempDir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try fm.createDirectory(at: tempDir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try Data().write(to: tempDir.appendingPathComponent(".DS_Store"))

        let tree = SkillDirectoryService.enumerate(tempDir)
        let topNames = tree.map(\.name)
        XCTAssertTrue(topNames.contains("SKILL.md"))
        XCTAssertTrue(topNames.contains("scripts"))
        XCTAssertFalse(topNames.contains(".git"))
        XCTAssertFalse(topNames.contains("node_modules"))
        XCTAssertFalse(topNames.contains(".DS_Store"))

        let scripts = tree.first { $0.name == "scripts" }
        XCTAssertEqual(scripts?.kind, .directory)
        XCTAssertEqual(scripts?.children?.first?.name, "run.py")
        XCTAssertEqual(scripts?.children?.first?.kind, .text)
    }

    func testDirectoriesSortBeforeFiles() throws {
        let fm = FileManager.default
        try Data().write(to: tempDir.appendingPathComponent("zfile.txt"))
        try fm.createDirectory(at: tempDir.appendingPathComponent("adir"), withIntermediateDirectories: true)

        let tree = SkillDirectoryService.enumerate(tempDir)
        XCTAssertEqual(tree.first?.name, "adir")
    }
}

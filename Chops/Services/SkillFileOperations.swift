import Foundation

enum SkillFileOperationError: LocalizedError, Equatable {
    case readOnly
    case cannotDeleteSkillFile
    case alreadyExists(String)
    case invalidName

    var errorDescription: String? {
        switch self {
        case .readOnly:
            return "This skill is read-only and can't be modified."
        case .cannotDeleteSkillFile:
            return "SKILL.md can't be deleted here. Delete the whole skill from the toolbar instead."
        case .alreadyExists(let name):
            return "\"\(name)\" already exists."
        case .invalidName:
            return "Enter a valid file name."
        }
    }
}

/// File management for a skill's bundled resources. All mutating operations are
/// gated by `isReadOnly` and refuse to delete `SKILL.md` (skill deletion lives
/// on the detail toolbar). `FileManager` changes also trigger the FileWatcher
/// re-scan, but callers should refresh the tree immediately.
enum SkillFileOperations {
    @discardableResult
    static func newFile(named name: String, in directory: URL, isReadOnly: Bool) throws -> URL {
        try guardWritable(isReadOnly)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SkillFileOperationError.invalidName }

        let url = directory.appendingPathComponent(trimmed)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw SkillFileOperationError.alreadyExists(trimmed)
        }
        try Data().write(to: url, options: .withoutOverwriting)
        return url
    }

    @discardableResult
    static func newFolder(named name: String, in directory: URL, isReadOnly: Bool) throws -> URL {
        try guardWritable(isReadOnly)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SkillFileOperationError.invalidName }

        let url = directory.appendingPathComponent(trimmed, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw SkillFileOperationError.alreadyExists(trimmed)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String, isReadOnly: Bool) throws -> URL {
        try guardWritable(isReadOnly)
        guard url.lastPathComponent != "SKILL.md" else {
            throw SkillFileOperationError.cannotDeleteSkillFile
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SkillFileOperationError.invalidName }

        let destination = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        guard destination != url else { return url }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw SkillFileOperationError.alreadyExists(trimmed)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    static func delete(_ url: URL, isReadOnly: Bool) throws {
        try guardWritable(isReadOnly)
        guard url.lastPathComponent != "SKILL.md" else {
            throw SkillFileOperationError.cannotDeleteSkillFile
        }
        try FileManager.default.removeItem(at: url)
    }

    private static func guardWritable(_ isReadOnly: Bool) throws {
        if isReadOnly { throw SkillFileOperationError.readOnly }
    }
}

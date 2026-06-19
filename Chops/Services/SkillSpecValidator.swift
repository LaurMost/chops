import Foundation

/// A single problem found while validating a skill against the Agent Skills
/// specification (https://agentskills.io/specification.md).
struct ValidationIssue: Equatable, Identifiable {
    enum Severity: Equatable {
        case error
        case warning
    }

    let field: String
    let severity: Severity
    let message: String

    var id: String { "\(field)|\(severity)|\(message)" }
}

/// Native Swift validator mirroring the Agent Skills frontmatter field
/// constraints. Two entry points encode the spec's dual posture:
/// strict when authoring (issues block Create) and lenient when discovering
/// existing files on disk (issues are non-blocking warnings).
enum SkillSpecValidator {
    static let maxNameLength = 64
    static let maxDescriptionLength = 1024
    static let maxCompatibilityLength = 500

    /// `^[a-z0-9]+(-[a-z0-9]+)*$` — lowercase alphanumerics separated by single
    /// hyphens, with no leading, trailing, or consecutive hyphens.
    static let namePattern = "^[a-z0-9]+(-[a-z0-9]+)*$"

    struct Input {
        var name: String
        var description: String
        var compatibility: String?
        /// Parent directory name to match against `name`. `nil` skips the check
        /// (e.g. single-file skills that are not directory-backed).
        var directoryName: String?

        init(name: String, description: String, compatibility: String? = nil, directoryName: String? = nil) {
            self.name = name
            self.description = description
            self.compatibility = compatibility
            self.directoryName = directoryName
        }
    }

    /// Strict validation for the authoring flow — every issue is an `error` and
    /// should block creation.
    static func validateForAuthoring(_ input: Input) -> [ValidationIssue] {
        validate(input, severity: .error)
    }

    /// Lenient validation for discovered files — every issue is a non-blocking
    /// `warning` so real-world skills still load.
    static func validateDiscovered(_ input: Input) -> [ValidationIssue] {
        validate(input, severity: .warning)
    }

    // MARK: - Rules

    private static func validate(_ input: Input, severity: ValidationIssue.Severity) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        let name = input.name
        if name.isEmpty {
            issues.append(ValidationIssue(field: "name", severity: severity, message: "Name is required."))
        } else {
            if name.count > maxNameLength {
                issues.append(ValidationIssue(
                    field: "name",
                    severity: severity,
                    message: "Name must be \(maxNameLength) characters or fewer (currently \(name.count))."
                ))
            }
            if !matchesNamePattern(name) {
                issues.append(ValidationIssue(
                    field: "name",
                    severity: severity,
                    message: "Name must be lowercase letters and numbers separated by single hyphens (e.g. my-skill)."
                ))
            }
            if let directoryName = input.directoryName, !directoryName.isEmpty, directoryName != name {
                issues.append(ValidationIssue(
                    field: "name",
                    severity: severity,
                    message: "Name should match the skill directory name (\"\(directoryName)\")."
                ))
            }
        }

        let description = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty {
            issues.append(ValidationIssue(field: "description", severity: severity, message: "Description is required."))
        } else if input.description.count > maxDescriptionLength {
            issues.append(ValidationIssue(
                field: "description",
                severity: severity,
                message: "Description must be \(maxDescriptionLength) characters or fewer (currently \(input.description.count))."
            ))
        }

        if let compatibility = input.compatibility, compatibility.count > maxCompatibilityLength {
            issues.append(ValidationIssue(
                field: "compatibility",
                severity: severity,
                message: "Compatibility must be \(maxCompatibilityLength) characters or fewer (currently \(compatibility.count))."
            ))
        }

        return issues
    }

    static func matchesNamePattern(_ name: String) -> Bool {
        name.range(of: namePattern, options: .regularExpression) != nil
    }
}

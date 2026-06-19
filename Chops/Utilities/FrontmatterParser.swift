import Foundation
import Yams

/// Parsed representation of a skill file's frontmatter plus body content.
///
/// `frontmatter` preserves the historical flat `[String: String]` contract of
/// top-level scalar keys. The typed fields (`license`, `compatibility`,
/// `allowedTools`, `metadata`) expose the remaining Agent Skills spec fields the
/// flat dictionary cannot represent (notably the nested `metadata` map).
struct ParsedSkill {
    var frontmatter: [String: String]
    var content: String
    var name: String
    var description: String
    var license: String?
    var compatibility: String?
    var allowedTools: String?
    var metadata: [String: String]

    init(
        frontmatter: [String: String],
        content: String,
        name: String,
        description: String,
        license: String? = nil,
        compatibility: String? = nil,
        allowedTools: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.frontmatter = frontmatter
        self.content = content
        self.name = name
        self.description = description
        self.license = license
        self.compatibility = compatibility
        self.allowedTools = allowedTools
        self.metadata = metadata
    }
}

enum FrontmatterParser {
    static func parse(_ text: String) -> ParsedSkill {
        let lines = text.components(separatedBy: "\n")

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ParsedSkill(frontmatter: [:], content: text, name: "", description: "")
        }

        var endIndex: Int?
        for i in 1 ..< lines.count where lines[i].trimmingCharacters(in: .whitespaces) == "---" {
            endIndex = i
            break
        }

        guard let end = endIndex else {
            return ParsedSkill(frontmatter: [:], content: text, name: "", description: "")
        }

        let yamlBlock = lines[1 ..< end].joined(separator: "\n")

        let contentStartIndex = min(end + 1, lines.count)
        let contentLines = Array(lines[contentStartIndex...])
        let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard let root = loadYAMLMap(yamlBlock) else {
            // Unparseable YAML — never crash and never drop the body.
            return ParsedSkill(frontmatter: [:], content: content, name: "", description: "")
        }

        return makeParsedSkill(from: root, content: content)
    }

    // MARK: - YAML loading

    /// Loads the frontmatter block into a `[String: Any]`. On a Yams throw we
    /// retry once with a lenient pass that quotes unquoted scalar values that
    /// contain a colon (a common real-world mistake like
    /// `description: Use when: the user asks about PDFs`).
    private static func loadYAMLMap(_ block: String) -> [String: Any]? {
        if let map = try? Yams.load(yaml: block) as? [String: Any] {
            return map
        }
        let quoted = quoteUnquotedColonValues(block)
        return try? Yams.load(yaml: quoted) as? [String: Any]
    }

    /// Wraps unquoted top-level scalar values that contain a `:` in double
    /// quotes so Yams can parse them. Only touches `key: value` lines whose
    /// value is not already quoted, not a block scalar (`|`/`>`), and not the
    /// start of a nested map.
    private static func quoteUnquotedColonValues(_ block: String) -> String {
        block.components(separatedBy: "\n").map { line -> String in
            guard let colonIndex = line.firstIndex(of: ":") else { return line }

            let keyPart = line[line.startIndex ..< colonIndex]
            // Indented lines belong to nested structures — leave them alone.
            guard keyPart == keyPart.drop(while: { $0 == " " || $0 == "\t" }) else { return line }

            let afterColon = line[line.index(after: colonIndex)...]
            let value = afterColon.trimmingCharacters(in: .whitespaces)

            guard value.contains(":") else { return line }
            guard !value.hasPrefix("\""), !value.hasPrefix("'") else { return line }
            guard !value.hasPrefix("|"), !value.hasPrefix(">") else { return line }

            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\(keyPart): \"\(escaped)\""
        }
        .joined(separator: "\n")
    }

    // MARK: - Mapping

    private static func makeParsedSkill(from root: [String: Any], content: String) -> ParsedSkill {
        var flat: [String: String] = [:]
        for (key, value) in root where !(value is [String: Any]) {
            flat[key] = scalarString(value)
        }

        let metadata = (root["metadata"] as? [String: Any]).map { map -> [String: String] in
            var result: [String: String] = [:]
            for (key, value) in map {
                result[key] = scalarString(value)
            }
            return result
        } ?? [:]

        return ParsedSkill(
            frontmatter: flat,
            content: content,
            name: flat["name"] ?? "",
            description: flat["description"] ?? "",
            license: flat["license"],
            compatibility: flat["compatibility"],
            allowedTools: flat["allowed-tools"],
            metadata: metadata
        )
    }

    /// Renders a YAML scalar back into the plain string the flat contract
    /// expects, stripping the quote artifacts the old line parser used to leave
    /// behind (e.g. `version: "1.0"` becomes `1.0`, not `"1.0"`).
    private static func scalarString(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let bool as Bool:
            return bool ? "true" : "false"
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let array as [Any]:
            return array.map { scalarString($0) }.joined(separator: ", ")
        case is NSNull:
            return ""
        default:
            return String(describing: value)
        }
    }
}

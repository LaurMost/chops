# Chops

A macOS app for discovering, organizing, and editing AI coding agent skills across tools. The domain is the filesystem of agent configuration files and the lifecycle of surfacing them in a unified UI.

## Language

### Discovery

**Skill**: A user-authored AI prompt instruction stored as a file (`SKILL.md`, `.md`, `.mdc`, `.toml`, or `.rules`) and discoverable by scanning tool directories. The atomic unit Chops manages.
_Avoid_: Prompt, instruction, command

**Agent**: A sub-agent definition file scanned from an `agents/` directory. Represents a named autonomous persona a tool can spawn to handle delegated tasks.
_Avoid_: Sub-agent file, agent config

**Rule**: A persistent instruction applied to every session of a tool, scanned from a `rules/` directory. Includes Cursor `.mdc` rules and Codex `.rules` files.
_Avoid_: Global prompt, persistent instruction

**Plugin**: A packaged collection of skills/agents/rules distributed via a marketplace and cached locally by the tool. Plugin skills are read-only (the cache is tool-managed). Distinct from user-authored skills in the global skills directory.
_Avoid_: Extension, package

**ToolSource**: An enum case identifying the coding agent tool that owns or uses a discoverable item (e.g. `.claude`, `.cursor`, `.codex`). Also determines which filesystem paths to scan.
_Avoid_: Tool, provider, agent (overloaded)

**ItemKind**: The discriminant (`skill | agent | rule`) classifying a single discovered item. Determines which sidebar section the item appears in and which icon/label is used.
_Avoid_: Type, category, kind (unqualified)

### Identity

**resolvedPath**: The canonical, stable identity of a discovered item. For filesystem items, this is the symlink-resolved absolute path. For plugin items, it is a synthetic URI (`claude-plugin:`, `cursor-plugin:`, `codex-plugin:`) with the volatile component (version hash) stripped out, so updates do not produce duplicate entries.
_Avoid_: File path, canonical path

**installedPaths**: The set of raw filesystem paths where a skill is physically present (e.g. both `~/.claude/skills/foo/SKILL.md` and `~/.cursor/skills/foo/SKILL.md` for a symlinked skill). Multiple paths collapse to one skill entry via the shared `resolvedPath`.
_Avoid_: Locations, copies

**isGlobal**: Whether a skill was found in a tool's global (home-directory) skills directory, as opposed to a project-local directory (e.g. `.claude/skills/` inside a repo).
_Avoid_: Global flag, scope

### Scanning

**SkillScanner**: The service that walks the filesystem, parses frontmatter, and upserts discovered items into SwiftData. Runs off the main thread; results are applied on the main actor.

**projectProbe**: A (subpath, tool, kind) triple used to locate tool-specific directories inside a project directory during custom-path scanning (e.g. `.cursor/rules` → Cursor rule).
_Avoid_: Project path, repo probe

**includePlugins**: A user preference controlling whether plugin caches are scanned. Off by default to avoid surfacing hundreds of read-only skills from installed plugin packages.

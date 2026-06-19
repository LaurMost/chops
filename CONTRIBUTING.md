# Contributing to Chops

Thanks for your interest in improving Chops! This is a native macOS app (SwiftUI + SwiftData) for discovering, organizing, and editing AI coding agent skills. Contributions of all sizes are welcome.

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Development setup

Requirements: macOS 15+ and Xcode with command-line tools.

```bash
git clone https://github.com/Shpigford/chops.git
cd chops
brew install xcodegen swiftlint swiftformat
xcodegen generate        # generates Chops.xcodeproj from project.yml
open Chops.xcodeproj      # then Cmd+R to build & run
```

The Xcode project is generated from `project.yml`. If you change `project.yml`, re-run `xcodegen generate`. Don't edit `Chops.xcodeproj` directly. See [README.md](README.md) for the full project tour.

## Core rules

These come straight from how the project is maintained — please follow them:

- **Always manually test.** After every change, build the app, launch it, and exercise the feature you changed. "Build succeeded" is not enough. If it's a UI change, look at it. If it's a data change, confirm the data.
- **No fallbacks.** Don't write fallback logic, graceful degradation, or backwards-compatibility shims. The product should work correctly via the primary code path. If something fails, fix the root cause. The codebase should be clean and direct, not defensive.

## Local checks (run before opening a PR)

CI runs these on every PR — run them locally first to get a fast signal:

```bash
# Formatting (SwiftFormat owns formatting; config: .swiftformat)
swiftformat Chops ChopsTests           # apply
swiftformat Chops ChopsTests --lint    # check only (what CI runs)

# Linting (SwiftLint owns correctness/code-smell rules; config: .swiftlint.yml)
swiftlint lint --strict                # warnings fail the build

# Build & test (XCTest target ChopsTests)
xcodebuild -scheme Chops -configuration Debug -destination 'platform=macOS' test
```

Unit tests cover the pure, logic-heavy code (parsers, `ToolSource`, agent response parsing, plugin-origin helpers). UI behavior is validated manually by building and running.

## Branching

Create a topic branch off `main` named `type/short-description`, where `type` matches the change (mirrors the commit types below):

```
feat/global-search
fix/swift6-concurrency-errors
chore/ci-and-linting
docs/contributing-guide
```

## Commit messages & PR titles

We use [Conventional Commits](https://www.conventionalcommits.org/). Both commit messages and PR titles should start with one of these types:

| Type | Use for |
| ---------- | ----------------------------------------------- |
| `feat`     | A new feature |
| `fix`      | A bug fix |
| `improve`  | An enhancement to an existing feature |
| `refactor` | A code change that neither fixes a bug nor adds a feature |
| `docs`     | Documentation only |
| `style`    | Formatting / SwiftFormat / SwiftLint fixes (no behavior change) |
| `test`     | Adding or updating tests |
| `build`    | Build system, tooling, or dependency changes |
| `chore`    | Maintenance that doesn't fit the above |

Example: `feat: install-to-tool menu in SkillMetadataBar`

Keep the subject in the imperative mood and under ~72 characters. Use the body to explain the *why* when it isn't obvious.

## Pull requests

1. Make sure the local checks above pass.
2. Open a PR against `main`. The [PR template](.github/PULL_REQUEST_TEMPLATE.md) will prompt you for a summary, the type of change, how you tested it, and a checklist.
3. Describe how you manually verified the change — this is required, not optional.
4. Link any related issue (e.g. `Closes #123`).
5. A maintainer reviews and merges.

## Labels

Issues are triaged with five canonical labels. The full list (with colors and descriptions) is the source of truth in [.github/labels.yml](.github/labels.yml) and is kept in sync on GitHub by the [labels workflow](.github/workflows/labels.yml).

| Label | Meaning |
| ----------------- | ----------------------------------------- |
| `needs-triage`    | Maintainer needs to evaluate this issue |
| `needs-info`      | Waiting on the reporter for more information |
| `ready-for-agent` | Fully specified, ready for an AFK agent |
| `ready-for-human` | Requires human implementation |
| `wontfix`         | Will not be actioned |

See [docs/agents/triage-labels.md](docs/agents/triage-labels.md) for how these map to agent workflows.

## Questions

Open a [GitHub issue](https://github.com/Shpigford/chops/issues) or reach out on X at [@Shpigford](https://x.com/Shpigford).

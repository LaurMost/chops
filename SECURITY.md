# Security Policy

## Supported versions

Chops is a rolling release distributed via GitHub Releases and auto-updated
through Sparkle. Only the latest released version is supported. Please update to
the newest version before reporting an issue.

## Reporting a vulnerability

Please report security vulnerabilities **privately** rather than opening a public
issue.

1. Preferred: use GitHub's private vulnerability reporting. Go to the
   [Security tab](https://github.com/Shpigford/chops/security/advisories/new)
   and choose "Report a vulnerability".
2. Alternatively, reach out to [@Shpigford](https://x.com/Shpigford) on X to
   arrange a private disclosure channel.

Please include:

- A description of the vulnerability and its impact
- Steps to reproduce (proof of concept if possible)
- The affected Chops version and your macOS version

We will acknowledge your report, investigate, and keep you updated on a fix. Once
a fix is released, we are happy to credit you in the release notes if you'd like.

## Threat model note

Chops intentionally runs **without the macOS app sandbox** so it can read and
write AI agent skill files across your home directory (`~/.claude/`, `~/.cursor/`,
`~/.codex/`, etc.). This is required for the app's core functionality.

Because of this, be mindful that:

- Chops can read and modify any file your user account can access.
- Skill files are read from disk and rendered/parsed; treat skills from untrusted
  sources with the same caution you would any executable instruction set.

Reports related to this elevated filesystem access, parser handling of malicious
files, or the agent CLI integrations (`claude` / `codex` invocation) are
especially welcome.

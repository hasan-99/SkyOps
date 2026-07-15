# ADR 0002: Rename to SkyOps, Rebuild as a Claude Code Plugin

## Status

Accepted — supersedes [ADR 0001](0001-use-copilotops-as-shared-ai-tooling.md).

## Context

ADR 0001 set up CopilotOps as a single source of truth for GitHub Copilot assets (instructions, prompts, skills), linked into each project's `.github` folder by a custom Node CLI (`install`/`init`/`link`/`health`/`doctor`/`validate`/`rollback`, later `codex-install` too).

The team's actual day-to-day work moved to Claude Code. Claude Code has its own native plugin format and its own install mechanism (`/plugin install`, `--plugin-dir`) — it doesn't read `.github` Copilot assets at all. Maintaining a GitHub-Copilot-shaped source of truth, a Codex-shaped copy of it, and a custom CLI to manage both was solving a problem that no longer matched how the framework is actually used.

## Decision

- Rename the framework to **SkyOps**.
- Rebuild it as a real, installable Claude Code plugin: `.claude-plugin/plugin.json` + `commands/` + `skills/` + `standards/` at the repo root.
- Remove `templates/.github/`, the repo's own self-referential `.github/`, the custom CLI (`src/`, `bin/`), `codex-install`, and every doc describing that install workflow.
- Fix the real bugs found while migrating (malformed frontmatter, missing fields, a hardcoded personal path) instead of carrying them forward.
- Add the framework's first implementation-time guards (`sky-async-guard`, `sky-i18n-guard`) — everything before this only caught problems at review time, after the code already existed.

## Consequences

Positive:

- No custom installer to maintain — Claude Code handles installing/loading the plugin itself.
- One content format instead of three (GitHub Copilot `.github`, a Codex copy, and now-obsolete tooling to keep them in sync).
- Two high-severity bug classes (SRV-H-001, SRV-H-006) are now caught while code is being written, not weeks later in review.

Tradeoffs:

- This is a breaking change (major version bump to 2.0.0) — anyone still relying on `copilotops install`/`link`/`codex-install` needs to switch to Claude Code's own plugin install flow instead.
- The GitHub Copilot and Codex delivery paths are gone. If either tool is needed again later, that's new work, not a revert — the old CLI and templates are still in git history if a starting point is ever needed.

## Final Standard

SkyOps is a Claude Code plugin, full stop. No other tool's format is maintained alongside it.

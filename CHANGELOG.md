# Changelog

All notable changes to SkyOps (formerly CopilotOps) should be documented here.

SkyOps follows semantic versioning:

- `PATCH` version, like `2.0.1`, for fixes, typos, docs, or small safe wording clarifications.
- `MINOR` version, like `2.1.0`, for new commands, new skills, or backward-compatible improvements.
- `MAJOR` version, like `3.0.0`, for breaking changes, folder structure changes, removed commands, or changed safety behavior.

## [2.0.0] - Rename to SkyOps, become a Claude Code plugin

### Changed

- Renamed the framework from CopilotOps to **SkyOps** and rebuilt it as a real, installable Claude Code plugin (`.claude-plugin/plugin.json` + `commands/` + `skills/` + `standards/` at the repo root), not a loose set of personal files.
- Fixed real bugs found during the migration: 3 files with malformed frontmatter, 3 files missing required frontmatter fields, and 2 files with a hardcoded personal path — now using `${CLAUDE_PLUGIN_ROOT}`.
- Full tone pass across every command/skill: same rules, plainer and warmer wording.

### Added

- `sky-async-guard` — implementation-time guard for SRV-H-001 (sync I/O inside async methods) and SRV-L-010 (missing/dropped CancellationToken). Fires while the code is being written, not just at review time.
- `sky-i18n-guard` — implementation-time guard for SRV-H-006 (culture/timezone-dependent DateTime parsing).
- `sky-comment-triage` — verifies a reviewer's comment against the code and checks for the same defect elsewhere before proposing a fix.

### Removed

- The entire GitHub Copilot delivery mechanism: `templates/.github/`, the repo's own self-referential `.github/`, and the custom Node CLI (`src/`, `bin/`, install/init/link/health/doctor/validate/rollback/codex-install) that existed solely to manage it. Claude Code installs/loads this plugin itself — no custom installer needed.
- CLI-specific docs (`ADMIN_SETUP.md`, `COMMAND_CATALOG.md`, `PRIVATE_GITHUB_INSTALL.md`, `PRIVATE_GITHUB_USER_GUIDE.html`, `TEAM_ONBOARDING.md`) — all described the now-removed install workflow.

## [1.3.0] - Replace Test Skill With Verification Workflow

### Changed

- Replaced the old `sky-tests` specialist skill with `sky-verification`.
- Updated planning and debug prompts to use the verification lane.
- Updated README command and skill reference sections.
- Kept `.github/skills` and `templates/.github/skills` aligned.

### Added

- Additional internal specialist skills for change summaries, decisions, evidence, and risk checks.
- Prompt command documentation for investigation, PR, and forensics workflows.
- HTML showcase for presenting CopilotOps workflow, parallel lanes, and token savings to the team.

## [1.2.0] - Add Private GitHub npx Install Preparation

### Added

- `copilotops install` command.
- Private GitHub repository npx install documentation.
- Validation checks for private GitHub package readiness.

### Notes

Publishing is not performed by this change. Invited users can use the private GitHub repository through npx after they have repository access and GitHub authentication.

## [1.1.0] - Add Doctor Diagnostics

### Added

- `copilotops doctor` CLI command.
- `/sky-doctor` read-only diagnostic prompt.
- Doctor checks for:
  - Node version
  - package/version consistency
  - framework file presence
  - template presence
  - target project CopilotOps integration
  - Git status
  - workflow safety
  - recommended next action

### Notes

This is a backward-compatible feature release.

## [1.0.0] - Initial Stable Internal Release

### Added

- CopilotOps Framework name and structure.
- Shared GitHub Copilot instructions.
- Shared prompt templates.
- Shared specialist skills.
- Token-saving specialist lane model.
- `APPROVE PLAN` planning safety rule.
- Command catalog.
- Team onboarding guide.
- Architecture decision record.
- Governance and prompt change policy.
- Local CLI framework structure.
- CLI commands:
  - `copilotops init`
  - `copilotops link`
  - `copilotops health`
  - `copilotops validate`
  - `copilotops rollback`
- Template folder:
  - `templates/.github/copilot-instructions.md`
  - `templates/.github/instructions`
  - `templates/.github/prompts`
  - `templates/.github/skills`

### Safety

- Planning prompts must remain read-only until the user types `APPROVE PLAN`.
- CopilotOps must be tested in one project before broad rollout.
- Project `.github/workflows` folders must not be overwritten.

### Notes

This is the first stable internal version of CopilotOps Framework.

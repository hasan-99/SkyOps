# Changelog

All notable changes to CopilotOps Framework should be documented here.

CopilotOps follows semantic versioning:

- `PATCH` version, like `1.0.1`, for fixes, typos, docs, validation fixes, or small safe prompt clarifications.
- `MINOR` version, like `1.1.0`, for new prompts, new skills, new CLI commands, or backward-compatible improvements.
- `MAJOR` version, like `2.0.0`, for breaking changes, folder structure changes, removed commands, or changed safety behavior.

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

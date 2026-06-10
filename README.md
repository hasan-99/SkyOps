# CopilotOps

Shared team instructions, prompts, skills, and workflow guidance for GitHub Copilot.

This repository is the single source of truth for reusable Copilot assets across all projects.

## User Prompts / Commands

- `/sky-task` - master planner for backend C#/.NET work.
- `/sky-fast` - fast planner for small-to-medium tasks.
- `/sky-debug` - bug investigation and fix planning.
- `/sky-docs` - generate documentation for a feature, module, endpoint, or flow.
- `/sky-explain` - explain code or flows in simple language.
- `/status-line` - show compact repo/session status.

## Internal Skills

These are used by the user prompts and are not normally invoked directly:

- `sky-api`
- `sky-data`
- `sky-service`
- `sky-security`
- `sky-performance`
- `sky-tests`

## Advanced Utility Commands

- `/sky-health` - verifies CopilotOps setup and repository readiness.
- `/sky-map` - creates a lightweight architecture map for a repository.

## Token-Saving Principle

Use small specialist lanes in parallel. Never give every agent the whole repository. Send each lane only the task summary, candidate files, and exact question it must answer.

CopilotOps is designed to reduce token usage by using focused parallel specialist agents instead of one large sequential investigation.

## Recommended First Run

When entering any project, run:

```text
/status-line
```

Then run:

```text
/sky-health
```

For a high-level understanding of a repo, run:

```text
/sky-map
```

## Documentation

* `docs/COMMAND_CATALOG.md`
* `docs/TEAM_ONBOARDING.md`
* `docs/decisions/0001-use-copilotops-as-shared-ai-tooling.md`

## Structure

```text
.github/
|-- copilot-instructions.md
|-- instructions/
|-- prompts/
`-- skills/
```

## Safety

Planning prompts must wait for:

`APPROVE PLAN`

before editing files, running builds, running tests, migrations, installs, formatters, or generators.

## Project Setup

Each project under `C:\SharedProjects` should link to shared CopilotOps assets.

Prefer linking these inside each project's `.github` folder:

* `.github\copilot-instructions.md`
* `.github\instructions`
* `.github\prompts`
* `.github\skills`

Do not replace a project's entire `.github` folder if it contains workflows or other project-specific files.

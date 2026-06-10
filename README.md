# CopilotOps Framework

CopilotOps Framework is an internal GitHub Copilot workflow framework for the team.

Current framework version:

```text
1.1.0
```

It provides:

- Shared Copilot instructions.
- Shared prompts.
- Shared specialist skills.
- Token-saving specialist lanes.
- Planning safety with `APPROVE PLAN`.
- Health checks.
- Architecture mapping.
- Validation.
- Full diagnostics with `copilotops doctor`.
- Rollback support.
- Local CLI tooling through `copilotops`.

## Version

Current framework version:

```text
1.1.0
```

CopilotOps uses semantic versioning:

* `1.0.1` for small fixes or safe prompt wording updates.
* `1.1.0` for new prompts, new skills, or new CLI commands.
* `2.0.0` for breaking changes or changed safety behavior.

## User Prompts / Commands

- `/sky-task` - master planner for backend C#/.NET work.
- `/sky-fast` - fast planner for small-to-medium tasks.
- `/sky-debug` - bug investigation and fix planning.
- `/sky-docs` - generate documentation for a feature, module, endpoint, or flow.
- `/sky-explain` - explain code or flows in simple language.
- `/status-line` - show compact repo/session status.
- `/sky-health` - verifies CopilotOps setup and repository readiness.
- `/sky-map` - creates a lightweight architecture map for a repository.
- `/sky-doctor` - deep setup and repository diagnostic when `/sky-health` is not enough.

## CLI Commands

- `copilotops init` - copy CopilotOps templates into a project.
- `copilotops link` - link project Copilot assets to central templates.
- `copilotops health` - check target project setup.
- `copilotops validate` - validate this framework repo.
- `copilotops doctor` - full framework and target project diagnostic.
- `copilotops rollback` - restore backed up CopilotOps-linked files/folders.

## Internal Skills

These are used by the user prompts and are not normally invoked directly:

- `sky-api`
- `sky-data`
- `sky-service`
- `sky-security`
- `sky-performance`
- `sky-tests`

## Token-Saving Principle

Use small specialist lanes in parallel. Never give every agent the whole repository. Send each lane only the task summary, candidate files, and exact question it must answer.

CopilotOps is designed to reduce token usage by using focused parallel specialist agents instead of one large sequential investigation.

## Local CLI Usage

From the CopilotOps repo:

```bash
node ./bin/copilotops.js --help
node ./bin/copilotops.js validate
node ./bin/copilotops.js doctor --source C:\SharedProjects\CopilotOps --target C:\SharedProjects\CS_Datafactory_v2
```

From a target project:

```bash
node C:\SharedProjects\CopilotOps\bin\copilotops.js health --target C:\SharedProjects\CS_Datafactory_v2
node C:\SharedProjects\CopilotOps\bin\copilotops.js doctor --target C:\SharedProjects\CS_Datafactory_v2 --source C:\SharedProjects\CopilotOps
node C:\SharedProjects\CopilotOps\bin\copilotops.js link --target C:\SharedProjects\CS_Datafactory_v2 --source C:\SharedProjects\CopilotOps --dry-run
```

## Future npm/npx Usage

After packaging or publishing internally:

```bash
npx copilotops health
npx copilotops init
npx copilotops link
npx copilotops validate
npx copilotops doctor
npx copilotops rollback
```

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

## Structure

```text
.github/
|-- copilot-instructions.md
|-- instructions/
|-- prompts/
`-- skills/

templates/.github/
|-- copilot-instructions.md
|-- instructions/
|-- prompts/
`-- skills/
```

## Safety

Planning prompts must wait for:

`APPROVE PLAN`

before editing files, running builds, running tests, migrations, installs, formatters, or generators.

Do not run broad linking across all projects until one test project works.

Recommended first test project:

```text
C:\SharedProjects\CS_Datafactory_v2
```

Project `.github/workflows` folders must not be overwritten.

## Project Setup

Each project under `C:\SharedProjects` should link to shared CopilotOps assets.

Prefer linking these inside each project's `.github` folder:

* `.github\copilot-instructions.md`
* `.github\instructions`
* `.github\prompts`
* `.github\skills`

Do not replace a project's entire `.github` folder if it contains workflows or other project-specific files.

## Documentation

* `docs/COMMAND_CATALOG.md`
* `docs/TEAM_ONBOARDING.md`
* `docs/decisions/0001-use-copilotops-as-shared-ai-tooling.md`

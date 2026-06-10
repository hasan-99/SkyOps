# ADR 0001: Use CopilotOps as Shared AI Tooling

## Status

Accepted

## Context

The team uses GitHub Copilot across multiple repositories under:

```text
C:\SharedProjects
```

We need consistent commands, prompts, skills, and instructions across all projects.

Copying the same files into every repository creates duplication, drift, and maintenance overhead.

We also need to reduce token usage during AI-assisted engineering. Large sequential investigations that send the whole repository to every agent waste context and make reviews harder.

## Decision

Use one shared repository/folder named:

```text
C:\SharedProjects\CopilotOps
```

as the single source of truth for GitHub Copilot assets:

* Instructions
* Prompts
* Skills
* Setup scripts
* Team documentation
* Command catalog

Projects should link only Copilot-specific assets from their `.github` folder:

* `.github\copilot-instructions.md`
* `.github\instructions`
* `.github\prompts`
* `.github\skills`

Do not replace the entire project `.github` folder because projects may have workflows or other project-specific GitHub files.

Use small specialist lanes in parallel. Never give every agent the whole repository. Send each lane only the task summary, candidate files, and exact question it must answer.

## Consequences

Positive:

* One source of truth.
* Faster updates.
* Consistent team behavior.
* Safer planning workflow.
* Easier onboarding.
* Less copy/paste maintenance.
* Lower token usage through focused parallel specialist agents.

Tradeoffs:

* Developers need to understand linked folders/files.
* The install script must avoid overwriting project-specific `.github` content.
* Projects should verify prompts and instructions after linking.

## Final Standard

Use CopilotOps for shared GitHub Copilot behavior.

Do not duplicate shared prompts or skills into every project.

CopilotOps is designed to reduce token usage by using focused parallel specialist agents instead of one large sequential investigation.

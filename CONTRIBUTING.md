# Contributing To CopilotOps Framework

CopilotOps Framework is the shared internal GitHub Copilot toolkit for the team.

## Change Policy

- Keep planning prompts read-only until `APPROVE PLAN`.
- Preserve .NET 6 / C# 10 guidance unless the team approves a framework-wide change.
- Preserve the token-saving specialist lane model.
- Do not add `.claude` files or folders.
- Do not overwrite project `.github/workflows` folders.
- Test changes in one project before broad rollout.

## Prompt Change Policy

Use semantic versioning:

- PATCH for fixes, typos, docs, validation fixes, or small safe prompt clarifications.
- MINOR for new prompts, new skills, new CLI commands, or backward-compatible improvements.
- MAJOR for breaking changes, folder structure changes, removed commands, or changed safety behavior.

## Validation

Before committing framework changes, run:

```bash
node ./bin/copilotops.js validate --source C:\SharedProjects\CopilotOps
```

# Contributing To SkyOps

SkyOps is the shared internal Claude Code toolkit for the team.

## Change Policy

- Keep planning commands read-only until `APPROVE PLAN`.
- Preserve .NET 6 / C# 10 guidance unless the team approves a framework-wide change.
- Preserve the token-saving parallel-lane model.
- Never hardcode an absolute path — use `${CLAUDE_PLUGIN_ROOT}` for anything inside this plugin that needs to reference another file in it.
- Test changes locally with `claude --plugin-dir <path to this repo>` before rolling out.

## Change Policy

Use semantic versioning:

- PATCH for fixes, typos, docs, or small safe wording clarifications.
- MINOR for new commands, new skills, or backward-compatible improvements.
- MAJOR for breaking changes, folder structure changes, removed commands, or changed safety behavior.

## Validation

Before committing framework changes:

1. Load it locally: `claude --plugin-dir C:\SharedProjects\SkyOps` and confirm every command/skill shows up with no errors.
2. Check frontmatter: every command/skill needs a single clean `---`-delimited block with `name`, `description`, `user-invocable`, and `disable-model-invocation`.
3. Grep for absolute paths (`C:\`, `~/`) — there should be none.

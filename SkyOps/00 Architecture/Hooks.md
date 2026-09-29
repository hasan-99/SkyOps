---
type: architecture
tags: [architecture, skyops, hooks]
author: Hasan Jahouse
version: 1.0
---

# Hooks

Wired via `hooks/hooks.json` (4 event types). Each has a `.js` primary implementation and a `.sh` fallback; the `.sh` stands down automatically if the `.js` runs first. `hook-doctor.js` shows which implementation is actually live (`--parity` diffs `.js` vs `.sh`; `--metrics` needs opt-in `SKYOPS_METRICS=1`). See [[sky-doctor]].

| Event | Matcher | Script | Purpose |
|---|---|---|---|
| `PreToolUse` | `Bash` | `guard-dispatch.js` | Single dispatcher (one process) runs `sql-guard` + `git-guard` in-process: asks before destructive SQL (DROP/TRUNCATE/DELETE-or-UPDATE-without-WHERE/`dotnet ef database drop`) and dangerous git (force push, push to main, `reset --hard`, `clean -f`, `branch -D`, history rewrites) |
| `SessionStart` | `compact` | `session-restore.js` | After compaction, points the session back at the active plan file + scope manifest for the current branch |
| `UserPromptSubmit` | every prompt | `knowledge-recall.js` | Scores the prompt against the lesson store, injects only strong matches — deterministic recall, doesn't rely on the model remembering to check. See [[sky-recall]]. |
| `PostToolUse` | `Edit\|Write\|MultiEdit` | `edit-dispatch.js` | Runs a `dotnet-format` reminder (auto-formats if `SKYOPS_AUTOFORMAT=1`) + a `sky-test` nudge after C# source edits in `CS_Datafactory_v2` |

## Design principle

Hooks **ask** rather than hard-block — one confirmation away for an intentional destructive op. A guard bug never blocks you; default is always allow.

## See also

[[sky-sql-destructive-guard]] (the model-invoked write-time counterpart to `git-guard`/`sql-guard`) · [[Repo Overview]]

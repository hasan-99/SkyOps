---
type: architecture
tags: [architecture, skyops]
author: Hasan Jahouse
version: 1.0
---

# Repo Overview

SkyOps (v2.9.0) is a Claude Code **plugin** for C#/.NET 6 backend work, installed via `claude --plugin-dir C:\SharedProjects\SkyOps` or the marketplace. See [[Home]].

| Folder | Contents |
|---|---|
| `agents/` | 8 agent definitions — parallel subagents dispatched by [[sky-review]], each pinned to an explicit model. See the [[sky-review-api]]-through-[[sky-reader]] notes. |
| `briefs/` | Generated HTML briefs — output of [[sky-explain]] |
| `commands/` | 27 user-invocable `/sky-*` command files — the top-level entry points |
| `docs/decisions/` | Architecture decision records |
| `hooks/` | Deterministic harness hooks (not prompt-based) — see [[Hooks]] |
| `plans/` | Durable per-ticket plan files written by [[sky-task]]/[[sky-fast]] (phases → waves → steps) |
| `scripts/` | 3 deterministic Node scripts invoked by commands: `lane-gate.js`, `skyops-lint.js`, `hook-doctor.js` |
| `skills/` | 19 background specialist skills — inspection lanes, judgement helpers, `sky-review` internals |
| `standards/` | `SRV-CATALOG.md` (16 codes) + one `SRV-*.md` per code + `GROUNDING.md` (evidence law) — see [[SRV Catalog]] |

## Change policy (`CONTRIBUTING.md`)

- Keep planning commands read-only until the user types `APPROVE PLAN`
- Preserve .NET 6 / C# 10 scope
- Preserve the parallel-lane token-saving model
- Never hardcode absolute paths — use `${CLAUDE_PLUGIN_ROOT}`
- Semantic versioning (PATCH/MINOR/MAJOR)
- Validate locally before committing framework changes — see [[sky-lint]]

## See also

[[Working Flow]] · [[Review Pipeline]] · [[Async Change Guard Pattern]]

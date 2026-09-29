---
type: command
tags: [command, skyops, plan-execute]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-debug.md`
**Repo description:** Fast bug-hunting skill for C#/.NET 6. Traces an error back to its root cause, checks impact via parallel specialists, proposes a fix (and a better way if one exists), then waits for APPROVE PLAN before changing code.
**user-invocable:** true · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-debug

Read-only bug-hunter.

- Traces root cause via the same parallel specialist lanes used by [[sky-task]] ([[sky-api]] / [[sky-data]] / [[sky-service]] / [[sky-security]] / [[sky-performance]] / [[sky-verification]]).
- Proposes the smallest fix.
- Waits for `APPROVE PLAN` before any edit — same approval gate as [[sky-task]]/[[sky-fast]].

## Compare

[[sky-investigate]] — broader backend/SQL/data/incident digging beyond a single bug. [[sky-forensics]] — deep incident reconstruction.

## See also

[[Working Flow]]

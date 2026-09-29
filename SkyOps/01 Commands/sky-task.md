---
type: command
tags: [command, skyops, plan-execute]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-task.md`
**Repo description:** Master planner and phased executor for backend C#/.NET 6 work. Writes a durable per-Jira plan file (phases -> waves -> steps mapped to requirements), waits for APPROVE PLAN, then implements phase by phase with a verification gate after each phase that checks Jira requirement coverage + SRV compliance + blast radius, and auto-fixes gaps before moving on.
**user-invocable:** true · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-task

Master planner + phased executor for larger backend work.

- Runs the 6 plan-stage skills ([[sky-api]] / [[sky-data]] / [[sky-service]] / [[sky-security]] / [[sky-performance]] / [[sky-verification]]) as needed, in parallel, read-only, to inspect the codebase before anything is written.
- Writes a **durable plan file** (`plans/`) — phases → waves → steps mapped to numbered requirements.
- **Stops** and waits for the user to type `APPROVE PLAN` before any edit — see the change policy in [[Repo Overview]].
- After approval, executes phase-by-phase with a post-phase verification gate: re-checks Jira coverage + SRV compliance + blast radius, auto-fixing gaps within budget.
- Argument `max-fix=N` (1–3, default 2) bounds auto-fix rounds *per phase*.
- Ends with the [[sky-next]] closing block.

## Compare

[[sky-fast]] — lighter/cheaper sibling for small/medium tasks. [[sky-debug]] — same approval gate, but read-only root-cause tracing instead of building a feature.

## See also

[[Working Flow]] · [[SRV Catalog]]

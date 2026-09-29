---
type: command
tags: [command, skyops, plan-execute]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-fast.md`
**Repo description:** Fast planner for small-to-medium C#/.NET tasks. Inspects affected files, builds a compact plan with flowchart, and waits for APPROVE PLAN before any code changes.
**user-invocable:** true · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-fast

Fast planner for small/medium tasks — the lighter, cheaper sibling of [[sky-task]].

- Same `APPROVE PLAN` gate as `sky-task`: writes a plan, stops, waits for explicit approval before editing.
- Uses **direct inspection** for small work instead of dispatching the 6 plan-stage skills; dispatches them (or any agent) only for genuinely independent lanes where parallelism actually pays for itself.
- Ends with the [[sky-next]] closing block.

## Compare

[[sky-task]] — full phased executor for larger work. [[sky-debug]] — read-only root-cause tracing with the same approval gate.

## See also

[[Working Flow]]

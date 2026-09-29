---
type: agent
tags: [agent, skyops, review-lane, async]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-review-service.md`
**Repo description:** Service review lane for sky-review. Checks handler and query correctness, SOLID, async and cancellation token flow (SRV-H-001, SRV-L-010), naming, code clarity, dead code, and parity of constants and category strings with sibling handlers. Read only. Dispatched in parallel by sky-review.
**model:** sonnet
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-service (agent)

Review lane dispatched by [[sky-review]]. Checks handler/query correctness, SOLID, **async and cancellation token flow (SRV-H-001, SRV-L-010)**, naming, code clarity, dead code, and parity of constants/category strings with sibling handlers. Read only.

The lane-gate (`scripts/lane-gate.js`) routes *every* `.cs` file into this lane automatically (`/\.cs$/i` catch-all) — see [[Review Pipeline]] step 4.

## Plan-stage counterpart

[[sky-service]]

## See also

[[Async Change Guard Pattern]] · [[sky-async-guard]] · [[SRV Catalog]]

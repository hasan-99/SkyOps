---
type: agent
tags: [agent, skyops, review-lane, performance]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-review-performance.md`
**Repo description:** Performance review lane for sky-review. Checks N+1 and per item DB calls, hot path inefficiency, unnecessary allocations, redundant work, and caching issues (SRV-M-007). Only reports a real, provable cost. Read only. Dispatched in parallel by sky-review.
**model:** sonnet
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-performance (agent)

Review lane dispatched by [[sky-review]]. Checks N+1 / per-item DB calls, hot-path inefficiency, unnecessary allocations, redundant work, and caching issues (SRV-M-007). Only reports a real, provable cost. Read only.

## Plan-stage counterpart

[[sky-performance]]

## See also

[[SRV Catalog]]

---
type: skill
tags: [skill, skyops, plan-stage, performance]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-performance/SKILL.md`
**Repo description:** Focused performance review skill for C#/.NET 6 backend planning. PLAN-stage lane: used by /sky-task and /sky-debug to inspect before code is written. The REVIEW-stage counterpart is the sky-review-performance agent, which reviews a diff after the fact. Pick by stage, not by topic.
**user-invocable:** false · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-performance

Plan-stage inspection lane: N+1 queries, projections, pagination, caching, hot paths. Read-only, max 5 findings. Used by [[sky-task]], [[sky-fast]], [[sky-debug]].

## Counterpart at review time

[[sky-review-performance]] (agent).

## See also

[[SRV Catalog]] (SRV-M-012 whole-table load, SRV-M-013 missing paging, SRV-M-007 non-atomic cache+TTL)

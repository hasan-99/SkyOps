---
type: skill
tags: [skill, skyops, plan-stage]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-data/SKILL.md`
**Repo description:** Focused data-layer inspection skill for EF Core, DbContext, entities, repositories, migrations, and queries on .NET 6. PLAN-stage lane: used by /sky-task and /sky-debug to inspect before code is written. The REVIEW-stage counterpart is the sky-review-data agent, which reviews a diff after the fact. Pick by stage, not by topic.
**user-invocable:** false · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-data

Plan-stage inspection lane: EF Core entities, DbContext, repositories, migrations, query filters, transactions, tracking behavior. Read-only, max 5 findings. Used by [[sky-task]], [[sky-fast]], [[sky-debug]].

## Counterpart at review time

[[sky-review-data]] (agent).

## See also

[[SRV Catalog]] (SRV-M-003 UoW boundary, SRV-H-014 untracked mutate, SRV-H-016 partial schema reach)

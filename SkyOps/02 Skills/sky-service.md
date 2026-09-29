---
type: skill
tags: [skill, skyops, plan-stage, async]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-service/SKILL.md`
**Repo description:** Focused service and business logic inspection skill for C#/.NET 6 repositories. PLAN-stage lane: used by /sky-task and /sky-debug to inspect before code is written. The REVIEW-stage counterpart is the sky-review-service agent, which reviews a diff after the fact. Pick by stage, not by topic.
**user-invocable:** false · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-service

Plan-stage inspection lane: services, interfaces, validators, domain rules, DI registrations, **async flow**. Read-only, max 5 findings. Used by [[sky-task]], [[sky-fast]], [[sky-debug]].

## Counterpart at review time

[[sky-review-service]] (agent) — explicitly reviews "async + cancellation flow, SRV-H-001, SRV-L-010." See [[Async Change Guard Pattern]].

## See also

[[sky-async-guard]] · [[SRV Catalog]]

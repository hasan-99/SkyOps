---
type: skill
tags: [skill, skyops, plan-stage]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-api/SKILL.md`
**Repo description:** Focused API inspection skill for C#/.NET 6 controllers, endpoints, DTOs, routes, and contracts. PLAN-stage lane: used by /sky-task and /sky-debug to inspect before code is written. The REVIEW-stage counterpart is the sky-review-api agent, which reviews a diff after the fact. Pick by stage, not by topic.
**user-invocable:** false · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-api

Plan-stage inspection lane: controllers, routes, DTOs, status codes, contracts. Read-only, max 5 findings, .NET 6-only scope. Used by [[sky-task]], [[sky-fast]], [[sky-debug]] during planning — inspects *before* code is written.

## Counterpart at review time

[[sky-review-api]] (agent) — reviews a diff *after* the fact. `sky-review` explicitly forbids dispatching this skill as a review lane; see [[Review Pipeline]].

## See also

[[SRV Catalog]] (SRV-L-004 fat controllers)

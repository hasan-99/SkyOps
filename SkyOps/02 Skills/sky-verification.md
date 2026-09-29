---
type: skill
tags: [skill, skyops, plan-stage, verification]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-verification/SKILL.md`
**Repo description:** Focused manual verification skill for C#/.NET 6 backend changes, SQL/data checks, incidents, and production-safe validation.
**user-invocable:** false · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-verification

Plans practical manual verification (this team may lack automated backend tests) — goal-backward, proving a change is actually *wired up* (DI registration, routing, `AddHostedService`, `DbSet` present), not just written. Auto-triggers after C# edits. Used inside [[sky-task]]/[[sky-fast]]/[[sky-debug]] planning and inside [[Review Pipeline]] step 10.

## See also

[[sky-risk]] · [[dotnet6-test-runner]]

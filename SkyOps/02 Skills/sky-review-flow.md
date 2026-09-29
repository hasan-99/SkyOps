---
type: skill
tags: [skill, skyops, review-internal]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-review-flow/SKILL.md`
**Repo description:** Performs the mandatory end-to-end integration review across all touched layers after specialist findings are collected.
**user-invocable:** false · **disable-model-invocation:** ?
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-flow

Mandatory end-to-end cross-layer check inside [[sky-review]] (step 8), run whenever a ticket crosses more than one architectural component. 11-point checklist: entry-point values flow downstream correctly, contracts match across layers, ID/key meaning preserved, nullability consistent, service calls the intended dependency, repo behavior matches service assumptions, data written matches the requirement, response maps from the correct source, error propagation, cancellation/async coherence, composed implementation satisfies the AC.

Canonical failure mode it exists to catch: *Controller sends CustomerId → Service treats it as AccountId → Repository query is locally valid* — locally-correct-but-globally-wrong.

## See also

[[Review Pipeline]] · [[sky-review-finalize]]

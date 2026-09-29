---
type: skill
tags: [skill, skyops, review-internal]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-srv-select/SKILL.md`
**Repo description:** Internal SRV shortlister. Given a change's shape — which layers, file types and operations it touches — returns the small set of SRV codes actually worth checking, plus the ones deliberately excluded and why. Used by review and implementation lanes so they check the relevant standards closely instead of sweeping all of them thinly.
**user-invocable:** false · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-srv-select

Shortlists which of the 16 [[SRV Catalog|SRV codes]] a change can plausibly violate — `likely`/`possible`, plus explicit exclusions with reasons — from the shape of the change (layers/files/operations). Front-loads reviewer focus inside [[sky-review]] (step 4). Does **not** replace the mandatory full [[sky-srv-standards]] sweep.

## See also

[[Review Pipeline]] · [[review-standards]]

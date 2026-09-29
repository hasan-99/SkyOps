---
type: skill
tags: [skill, skyops, judgement-helper]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-repo-profile/SKILL.md`
**Repo description:** Internal repository profiler. Establishes the facts every other lane keeps rediscovering — solution and project layout, target framework, test framework and conventions, build and test commands, sibling-repo references, and where handlers, repositories and validators live. Cached per repo so one lookup serves the whole session.
**user-invocable:** false · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-repo-profile

Establishes repo facts once — layout, build/test commands, test conventions, sibling-repo constraints — cached at `.skyops/profile.md`, so every other lane stops rediscovering the same facts from scratch.

## See also

[[sky-scope]] (same caching philosophy, applied to the diff instead of the repo shape)

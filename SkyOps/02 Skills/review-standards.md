---
type: skill
tags: [skill, skyops, judgement-helper]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/review-standards/SKILL.md`
**Repo description:** Classifies review findings against official review standards and SRVs.
**user-invocable:** false · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# review-standards

Classifies findings **already produced** against `SRV-CATALOG.md` — does not itself review code. Always reads the catalogue at `C:\SharedProjects\SkyOps\standards\SRV-CATALOG.md` first (never the stale `~/.claude/standards` copy). Used in [[Review Pipeline]] step 9 alongside [[sky-evidence]].

## See also

[[SRV Catalog]] · [[sky-srv-standards]] (the agent that does the actual catalogue-wide code sweep)

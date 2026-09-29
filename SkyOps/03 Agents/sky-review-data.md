---
type: agent
tags: [agent, skyops, review-lane]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-review-data.md`
**Repo description:** Data review lane for sky-review. Checks repository and query correctness, de-duplication and key normalization, unit of work and DbContext boundaries (SRV-M-003), and culture or timezone sensitive parsing and formatting in persistence paths (SRV-H-006). Confirms the acceptance criteria behaviors. Read only. Dispatched in parallel by sky-review.
**model:** sonnet
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-data (agent)

Review lane dispatched by [[sky-review]]. Checks repository/query correctness, de-duplication and key normalization, Unit-of-Work/DbContext boundaries (SRV-M-003), and culture/timezone-sensitive parsing in persistence paths (SRV-H-006). Confirms the acceptance-criteria behaviors. Read only.

## Plan-stage counterpart

[[sky-data]]

## See also

[[SRV Catalog]] · [[sky-i18n-guard]]

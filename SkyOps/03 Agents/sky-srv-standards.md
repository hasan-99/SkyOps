---
type: agent
tags: [agent, skyops, review-lane]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-srv-standards.md`
**Repo description:** Dedicated SRV compliance agent. Sweeps a code diff against every SRV in the review catalogue, one code at a time, so no standard is missed. Dispatched by sky-review as a mandatory parallel lane on every review. Returns each violated SRV with file:line evidence, and confirms which SRVs were checked and found clean. Read only.
**model:** sonnet
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-srv-standards (agent)

Dedicated SRV compliance agent. Sweeps a code diff against **every** SRV in the catalogue, one code at a time, so nothing is missed. Dispatched by [[sky-review]] as a **mandatory** parallel lane on every review — the only lane outside the deterministic lane-gate selection (see [[Review Pipeline]] step 4). Read only. Returns each violated SRV with `file:line` evidence, and confirms which SRVs were checked and found clean.

Unlike the other lane agents, this is the only one that reads the full [[SRV Catalog]] rather than a shortlisted subset.

## See also

[[sky-srv-select]] (the pre-review shortlist, not a substitute for this sweep) · [[review-standards]]

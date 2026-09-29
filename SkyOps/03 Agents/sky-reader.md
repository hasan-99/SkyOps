---
type: agent
tags: [agent, skyops, meta]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-reader.md`
**Repo description:** Narrow read-only repository locator for mechanical fact gathering. Finds files, symbols, call sites, tests, and exact file:line anchors without making correctness, risk, architecture, security, data, or Jira verdicts.
**model:** haiku
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-reader (agent)

New in v2.9.0. Runs on Haiku — bounded, mechanical lookup only (e.g. "does this file exist," "what does this function currently do"). Never makes correctness or risk verdicts; that judgement stays with the session model per SkyOps' model-routing table.

## See also

[[Repo Overview]] · [[sky-srv-standards]]

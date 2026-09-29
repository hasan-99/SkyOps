---
type: agent
tags: [agent, skyops, review-lane]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-review-api.md`
**Repo description:** API review lane for sky-review. Checks routing, HTTP verbs, route templates, status codes, request and response contracts, ProducesResponseType attributes, and controller thinness (SRV-L-004). Read only. Dispatched in parallel by sky-review.
**model:** haiku
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-api (agent)

Review lane dispatched by [[sky-review]] (never by name confusion with the skill). Checks routing, HTTP verbs, route templates, status codes, request/response contracts, `ProducesResponseType`, and controller thinness (SRV-L-004). Read only. Dispatched in parallel by [[sky-review]] alongside the other lanes — see [[Review Pipeline]].

## Plan-stage counterpart

[[sky-api]] — inspects *before* code is written; this agent reviews the diff *after*.

## See also

[[SRV Catalog]]

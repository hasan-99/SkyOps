---
type: agent
tags: [agent, skyops, review-lane, security]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `agents/sky-review-security.md`
**Repo description:** Security review lane for sky-review. Checks authorization and authentication on the new path, injection risk, secret handling, unsafe deserialization, and cross tenant reachability. Read only. Dispatched in parallel by sky-review.
**model:** sonnet
**tools:** Read, Grep, Glob, Bash
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-security (agent)

Review lane dispatched by [[sky-review]]. Checks authorization/authentication on the new path, injection risk, secret handling, unsafe deserialization, and cross-tenant reachability. Read only. Lane-gate routes *any controller change* into this lane even without an "auth" keyword — new endpoint = new attack surface.

## Plan-stage counterpart

[[sky-security]]

## See also

[[SRV Catalog]]

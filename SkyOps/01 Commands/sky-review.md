---
type: command
tags: [command, skyops, review]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-review.md`
**Repo description:** Master Jira and code review orchestrator. Reads Jira context, resolves exact ticket scope, starts build and tests in the background, dispatches specialist review agents in parallel, validates end-to-end flow, and produces a short paste-ready Jira review.
**user-invocable:** true · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-review

The big orchestrator — the only command that dispatches the `sky-review-*` **agents**. Full 12-step breakdown: [[Review Pipeline]].

Dispatches, in order: [[sky-review-context]] → [[sky-review-scope]] (reusing a [[sky-scope]] manifest if fresh) → background build/test → [[sky-srv-select]] + deterministic `lane-gate.js` → parallel lane agents ([[sky-review-api]] / [[sky-review-data]] / [[sky-review-service]] / [[sky-review-security]] / [[sky-review-performance]] as selected) + mandatory [[sky-srv-standards]] → [[sky-review-flow]] cross-layer check → [[sky-evidence]] + [[review-standards]] validation against [[SRV Catalog]] → [[sky-risk]] + [[sky-verification]] → [[sky-review-finalize]] verdict + paste-ready Jira comment (never posted) → [[sky-learn]] silent capture → [[sky-next]].

## Compare

[[sky-comment-triage]] — verifies one reviewer comment, not a full review. [[sky-jira-verify]] — requirement traceability, not an SRV defect review.

## See also

[[Async Change Guard Pattern]] · [[SRV Catalog]]

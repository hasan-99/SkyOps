---
type: command
tags: [command, skyops, scope]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-scope.md`
**Repo description:** Reads the branch diff once and writes a reusable scope manifest — changed files, changed symbols, affected projects, covering tests, Jira requirements, and candidate SRVs. /sky-review, /sky-test, /sky-pr, /sky-task and /sky-jira-verify then reuse that manifest instead of each rediscovering the same diff. The single biggest token saver in the framework. Read-only.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-scope

Reads the branch diff **once** and writes a reusable manifest `.skyops/scope/<key>.scope.md` — described in its own frontmatter as "the single biggest token saver in the framework." Reused instead of rediscovered by [[sky-review]] ([[sky-review-scope]]), [[sky-test]], [[sky-pr]], [[sky-task]], and [[sky-jira-verify]].

The manifest is a **cache, not a source of truth** — staleness is checked by comparing its stored `head_sha` against the current `HEAD`; a mismatch means rediscovery, not a stale-trust.

## See also

[[Review Pipeline]] (step 2 consumes this) · [[sky-test]]

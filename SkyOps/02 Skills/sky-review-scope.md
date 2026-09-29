---
type: skill
tags: [skill, skyops, review-internal]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-review-scope/SKILL.md`
**Repo description:** Builds the exact Jira-ticket code scope from tagged commits, changed files, changed methods, tests, and minimal dependency context.
**user-invocable:** false · **disable-model-invocation:** ?
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-scope

Second step of [[sky-review]] (see [[Review Pipeline]] step 2). Builds the exact ticket code scope from `git log --grep=<KEY>`-tagged commits — never a raw branch-vs-master diff. First checks for a current [[sky-scope]] manifest matching `HEAD`'s `head_sha` and reuses it if fresh; otherwise rediscovers and says so. Dependency commits are pulled in only with concrete justification, one-hop context only.

## See also

[[sky-review-context]] · [[sky-scope]]

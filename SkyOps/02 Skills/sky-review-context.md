---
type: skill
tags: [skill, skyops, review-internal]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-review-context/SKILL.md`
**Repo description:** Resolves Jira requirement, acceptance criteria, comments, repositories, and review branches before code review begins.
**user-invocable:** false · **disable-model-invocation:** ?
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-context

First step of [[sky-review]] (see [[Review Pipeline]] step 1). Resolves Jira key/summary/description/AC/comments, repos, and branches. Resolution priority: explicit user instruction → latest "Branches for review" comment → latest relevant comment → ticket description. Code review does not start until branch/repo scope is resolved.

## See also

[[sky-review-scope]] · [[sky-jira-verify]]

---
type: command
tags: [command, skyops, investigate]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-drift.md`
**Repo description:** Answers "where has this change actually reached?" — is it on the feature branch, is it really on dev, is dev actually running it, and do the tests exist there too. Catches the case where code is correct on a branch but missing from dev or from the deployed environment. Read-only. Does not re-check acceptance criteria; that is /sky-jira-verify.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-drift

Separates *written* vs *merged* vs *running* — is a fix really on Dev, and is Dev actually running it. Answers the "did this ship" question that a plain git log can't.

## See also

[[sky-investigate]] · [[sky-verify-fix]] · [[Working Flow]]

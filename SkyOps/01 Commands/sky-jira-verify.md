---
type: command
tags: [command, skyops, review]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-jira-verify.md`
**Repo description:** Jira requirement coverage verifier. Fetches the ticket context and valid comments, resolves the branch, then dispatches parallel subagents to check the branch changes against every Jira requirement and reports Match, Mismatch, Remaining, and Suggestions.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-jira-verify

Requirement-traceability check — not an SRV defect review. Maps every ticket requirement to real branch changes and reports Match / Mismatch / Remaining / Suggestions, via parallel subagents. `disable-model-invocation: false` (can also self-fire).

## Compare

[[sky-review]] finds defects; this confirms coverage.

## See also

[[sky-draft-comment]] · [[sky-scope]]

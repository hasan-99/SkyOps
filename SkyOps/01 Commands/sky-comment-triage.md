---
type: command
tags: [command, skyops, review]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-comment-triage.md`
**Repo description:** Use whenever the user shares a reviewer's Jira/PR comment or code-review feedback and asks whether it's valid, how to fix it, or what to reply. Verifies the claim against the actual codebase, checks whether the same defect pattern exists elsewhere via parallel lanes, and proposes the smallest safe fix. Read-only — never applies the fix itself.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-comment-triage

Verifies a reviewer's comment is actually right before acting on it — checks the claim against the real codebase rather than trusting it blindly.

## See also

[[sky-review]] · [[sky-verify-fix]]

---
type: command
tags: [command, skyops, review]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-verify-fix.md`
**Repo description:** Verifies one specific fix — a resolved bug or an addressed review comment — instead of re-running a full review. Confirms the original defect is actually gone, that the fix did what it claimed, and that it broke nothing adjacent. Use after /sky-debug, /sky-comment-triage, or a single review finding. Read-only.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-verify-fix

Verifies one specific fix without re-running a whole [[sky-review]] pass — the targeted, cheap alternative when you just need to confirm one thing landed correctly.

## See also

[[sky-drift]] · [[sky-comment-triage]]

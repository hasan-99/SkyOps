---
type: command
tags: [command, skyops, learning]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-learn.md`
**Repo description:** Save a reusable lesson so the next session benefits — a fix that worked, a recurring bug pattern, an SRV gotcha, or a team/repo preference. Fires automatically at the end of /sky-review, /sky-debug, /sky-comment-triage and /sky-task for every CONFIRMED finding, and on request ("remember this", "save this", "note for next time"). Writes only to the machine-local lesson store — never to source code.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-learn

Saves a reusable lesson to the machine-local knowledge store. Auto-fires at the end of [[sky-review]], [[sky-debug]], [[sky-comment-triage]], and [[sky-task]] — but only for **confirmed findings** with real `file:line` proof.

Duplicate lessons increment a `hits` counter instead of duplicating; a recurring hit count is what justifies promoting a lesson into a dedicated write-time guard like [[sky-async-guard]] — see [[Async Change Guard Pattern]].

## See also

[[sky-recall]] · [[sky-lesson-export]] · [[Review Pipeline]] (step 12)

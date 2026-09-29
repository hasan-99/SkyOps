---
type: command
tags: [command, skyops, learning]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-lesson-export.md`
**Repo description:** Share a specific vetted lesson from the machine-local store into the current repo's .skyops/knowledge/ so the team gets it too. Opt-in and one lesson at a time — the private store is never bulk-published. Writes a file in the working repo but never commits it.
**user-invocable:** true · **disable-model-invocation:** true
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-lesson-export

Shares one vetted lesson from the private machine-local store into the current repo's `.skyops/knowledge/`. Gated by a secrets/staleness check; opt-in, one lesson at a time, never commits.

## See also

[[sky-learn]] · [[sky-recall]]

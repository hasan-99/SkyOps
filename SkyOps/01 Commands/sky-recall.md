---
type: command
tags: [command, skyops, learning]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `commands/sky-recall.md`
**Repo description:** Recall prior lessons saved by /sky-learn before you investigate, fix, or review — so known fixes, repo patterns, SRV gotchas, and team preferences surface first instead of being re-derived. The recall hook injects strong matches automatically on every prompt; invoke this for a deliberate, wider search ("have we seen this", "any notes on X", "recall"). Read-only.
**user-invocable:** true · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# /sky-recall

Deliberate, wider search of saved lessons. Everyday recall is automatic via the `knowledge-recall.js` hook (see [[Hooks]]), which scores every prompt against the lesson store and injects only strong matches — this command is for when you want to search deliberately instead. Pure read-only informational command — omits the [[sky-next]] closing block.

## See also

[[sky-learn]] · [[sky-lesson-export]]

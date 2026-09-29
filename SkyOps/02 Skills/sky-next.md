---
type: skill
tags: [skill, skyops, judgement-helper]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-next/SKILL.md`
**Repo description:** Internal closing block for every SkyOps command. Turns the end of a run into a decision — what is still open (gaps, unrun checks, missing tests, unverified claims, blocked criteria) and the single best next action, as a command you can type. Keeps unfinished work visible instead of letting a report end on a green note.
**user-invocable:** false · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-next

The mandatory closing block appended to almost every command — up to 3 "Open" unfinished items + one "Next" command to run. Omitted for pure read-only informational commands: [[sky-explain]], [[sky-map]], [[sky-recall]].

## See also

[[sky-task]] · [[sky-review]]

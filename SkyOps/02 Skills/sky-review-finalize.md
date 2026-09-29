---
type: skill
tags: [skill, skyops, review-internal]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-review-finalize/SKILL.md`
**Repo description:** Applies deterministic review decisions and formats the short Sky Review result and paste-ready Jira comment.
**user-invocable:** false · **disable-model-invocation:** ?
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-review-finalize

Last analytical step of [[sky-review]] (step 11). Applies the deterministic verdict rubric:

- **Block** — proven Critical, severe security/data-integrity defect, or an equivalent build/test failure
- **Request Changes** — blocking High, or a Medium blocking an AC, or multiple unsafe Mediums
- **Approve With Comments** — non-blocking Medium/Low/Optional only
- **Approve** — clean

Formats the short verdict and a paste-ready Jira comment. **Never posts it** — publishing needs separate explicit per-action permission.

## Compare

[[sky-draft-comment]] drafts a **delivery/completion** comment; this drafts a **review verdict** comment. Different formats.

## See also

[[Review Pipeline]] · [[sky-learn]]

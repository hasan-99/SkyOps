---
type: skill
tags: [skill, skyops, judgement-helper]
author: Hasan Jahouse
version: 1.0
---

<!-- sky-sync:start -->
**Repo source:** `skills/sky-risk/SKILL.md`
**Repo description:** Internal risk assessment skill for C#/.NET 6 backend, SQL, data, incident, production, and PR work. Identifies what can break, risk level, mitigation, rollback, and safe next checks.
**user-invocable:** false · **disable-model-invocation:** false
*Synced 2026-09-25 by `scripts/sky-generate-vault.js` — hand-authored content below this block is preserved on re-run.*
<!-- sky-sync:end -->

# sky-risk

Internal judgement helper — what can break, severity, mitigation, rollback, max 5 risks. Rates User/Data/Security/Performance/Operational risk internally. Includes a "Hard Gate — Destructive Patterns" check, mirrored at write-time by [[sky-sql-destructive-guard]]. Used in [[Review Pipeline]] step 10 alongside [[sky-verification]].

## See also

[[sky-decision]] · [[sky-sql-destructive-guard]]

# Sky Task — plan file template

Read this only when you are about to WRITE or RESTRUCTURE a plan file.
It is not needed to plan, to execute a phase, or to resume.

### Plan file template

````markdown
# Sky Task Plan: <KEY> <task title>

## Meta
- **Jira:** <KEY> (<url or N/A>)
- **Repos:** <repo(s)> under C:\SharedProjects
- **Branch(es):** <HJ/CLS-... per repo, or "to create off latest dev">
- **Task type:** <Bug fix | New feature | Refactor | Investigation | Test-only | Config/deploy | Security/authz | Database/migration | Docs/prompt>
- **Planning depth:** Tiny | Standard | Deep
- **Security level:** none | low | medium | high
- **Performance level:** none | low | medium | high
- **Overall risk:** low | medium | high
- **Max-fix (per phase):** 1 | 2 | 3   (effective value; default 2)
- **Status:** PLANNING | AWAITING APPROVAL | EXECUTING (phase N) | VERIFYING (phase N) | DONE | BLOCKED
- **Last updated:** <YYYY-MM-DD>

## Goal
<One sentence.>

## Assumptions
- <Only assumptions that matter.>

## Requirements (spine)
| id | requirement | source |
|----|-------------|--------|
| R1 | ... | AC / description / comment |
| R2 | ... | ... |

## Requirement Status
| ID | Requirement | Phase | Status | Evidence |
|----|-------------|-------|--------|----------|
| R1 | ... | 1 | Planned | — |
| R2 | ... | 2 | Planned | — |
<!-- Status: Planned | Implemented | Verified | Blocked. Keep exactly one status per requirement.
     Planned at plan time -> Implemented when a phase finishes its code for it -> Verified only after that phase's gate passes -> Blocked if it cannot proceed safely. -->

## Blast Radius
| area | what could be affected | decision |
|------|------------------------|----------|
| <file/contract/table/job> | <caller / consumer / data / tenant> | update in scope / verify only / out of scope (why safe) |

## SRV Watchlist
- SRV-XXX-NNN <one line why it applies to this change>

## Specialist Findings (summary)
- **API / Service / Data / Security / Performance / Verification:** <one line each or N/A>

## Phases

### Phase 1 <name> [ ] pending
- **Covers:** R1, R2
- **SRV focus:** <subset>
- **Blast radius:** <subset>
- **Waves:**
  - **Wave 1a** (parallel): <steps that are independent>
  - **Wave 1b** (parallel): <steps that are independent>
  - *(or "single wave" if no parallelism)*
- **Steps:**
  1. <concrete step> -> satisfies R1 -> <reason>
  2. <concrete step> -> satisfies R2 -> <reason>
- **Gate definition of done** (checks run at the plan's planning depth see Execution Engine step 2; Tiny lightweight, Standard normal, Deep broader):
  - Requirements R1, R2 verified as Match against the diff (mandatory at every depth).
  - SRVs relevant to the changed code clean on the phase diff (Tiny: relevant subset only; Standard/Deep: full watchlist subset).
  - Blast-radius items verified: no bystander regressions (mandatory at every depth; Deep adds a broader consumer/contract/data-flow sweep).
  - Build passes (if buildable) / tests or manual verification defined and passing (Tiny: minimum relevant signal).
- **Gate result:** <filled during execution: PASS / gaps found + fixes applied / BLOCKED>

### Phase 2 <name> [ ] pending
...

## Final Verification (all phases)
- <filled at the end: full requirement coverage, full SRV self-check, full-task build/manual/regression result>

## Execution Log
- <appended during execution: phase started/finished, gate verdicts, gaps, auto-fixes, decisions>

## Out Of Scope
- <What this plan will not cover.>
````

---


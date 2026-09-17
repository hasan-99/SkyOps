---
name: sky-review-finalize
description: Applies deterministic review decisions and formats the short Sky Review result and paste-ready Jira comment.
user-invocable: false
---

# Sky Review Finalize

Finalize only after aggregation, the joined build and test result, cross-flow review, the SRV sweep,
evidence validation, risk, and verification planning.

## Decision Rules

### Block

Use when there is:

* a proven Critical finding
* a severe proven security or data-integrity defect that makes release unsafe
* a build/test implementation failure that makes the ticket unusable and is equivalent to Critical impact

### Request Changes

Use when there is:

* a blocking High finding
* a Medium finding that directly prevents an acceptance criterion
* multiple Medium findings that make the implementation unsafe or incomplete

### Approve With Comments

Use when:

* only non-blocking Medium findings remain
* only Low or Optional findings remain
* implementation is correct but proven minor improvements remain

### Approve

Use when:

* no reportable findings remain
* code-verifiable acceptance criteria are satisfied
* build/test evidence shows no implementation failure

## Missing Evidence

If build/tests cannot run due to environment or tooling:

* do not treat that as implementation failure
* lower overall confidence
* state it as a verification gap
* base the verdict on proven implementation findings

## Output Rules

Short and clear. The result shows only:

1. Verdict
2. Acceptance criteria status
3. Actual findings
4. Build and test result
5. Important verification gaps

Everything else is working material, not output.

* Omit any section that is empty. Never print a heading whose only content is
  `No reportable findings`, `None`, or `N/A`.
* No lane table, no scope dump, no risk matrix, no verification plan, no confidence table,
  unless a real gap or a real risk needs stating — then it is one line, not a section.
* No SkyOps internals: lane names, agent names, skill names, step numbers, and catalogue paths
  never appear in the output.
* Requirement coverage leads, findings follow, the next action closes.

## Result Format

```text
Review — <KEY>

Verdict: <Approved | Approved With Comments | Changes Requested | Blocked>

<severity marker> <Severity> — <short title>
File: <repo relative path> (line N)<, SRV-X-NNN when catalogued>
<one or two lines: the problem and why it matters>
Fix: <the precise required change>

<next finding, most severe first>

Build <passed | failed | not run: reason>. Tests <passed | failed | not run: reason>.
<AC1, AC2, AC4 verified; AC3 unverified — what blocks it>
<one line per material verification gap, only when one exists>
```

Severity markers:

* 🔴 Critical or High
* 🟡 Medium
* 🟢 Low or Optional

If there are no findings, go straight from the verdict line to the build and acceptance criteria
lines. Do not announce that there were none.

Every finding keeps its `file (line N)` — a finding without a location cannot be acted on, and the
review contract is no finding without proof. Everything else about a finding stays to two or three
lines. If a deliberately unraised defect could be mistaken for an oversight, add one line saying so.

Never present manual or live verification as completed.

Worked example:

```text
Review — CLS-15342

Verdict: Approved With Comments

🟡 Medium — Missing regression test.
File: tests/Handlers/AlertHandlerTests.cs (line 84)
The new branch for suppressed alerts has no coverage, so a regression here ships silently.
Fix: Add one focused test for the suppressed-alert path.

🟢 Low — Outdated code reference.
File: src/Handlers/AlertHandler.cs (line 31)
The comment still points at the removed AlertQuery.
Fix: Update the reference.

Build passed. Tests passed.
AC1, AC2, AC4 verified; AC3 unverified — it needs a live queue and cannot be checked from code.
```

## Jira Comment

Always output a short paste-ready fenced block after the result.

Rules:

* Line one: `<KEY> — <verdict>`
* Verdict:
  * Approved
  * Approved With Comments
  * Changes Requested
  * Blocked
* Line two: one short sentence describing implementation and build/test result.
* Then a blank line.
* Findings most severe first.
* If there are no findings, stop after line two.
* Never include an empty Security, Data, Performance, Risk, or Verification section. If the lane
  found nothing, it does not appear.
* No internal SkyOps detail: no lane, agent, skill, or step names, no catalogue paths, no note that
  a review tool was used. Team SRV codes are fine — they are the shared review vocabulary.
* No Branches line.
* No `Sky Review:` prefix.
* Never use dash punctuation in Jira prose.

Finding layout:

```text
🔴 <SRV code or category>: <short title>
File: <repo relative path> (line N)
SRV: <SRV code and title, or "not catalogued">

<problem code>

<why and risk>

Fix:

<corrected code or precise required change>
```

Never include manual/live verification as completed.

Never post the comment. Output it and stop.

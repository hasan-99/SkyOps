---
name: sky-review-finalize
description: Internal lane of /sky-review. Formats the final report and the paste-ready Jira comment. Do not invoke on its own.
user-invocable: false
---

# Sky Review Finalize

Finalize only after aggregation, cross-flow review, SRV validation, evidence validation, risk, and verification planning.

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
* state missing evidence in the full report
* base the verdict on proven implementation findings

## Full Report

```text
# Sky Review Report

## Requirement Understanding
* Task
* Expected Change
* Must Stay The Same
* Impacted Flow
* Assumptions

## Resolved Scope
* Jira
* Repositories
* Branches or commit fallback
* Ticket-tagged commits
* Changed files
* Added dependency context

## Review Execution
| Lane | Status | Why Selected | Notes |

Cross-Flow Review: Completed

## Evidence
* Build result
* Test result
* Passed
* Failed
* Skipped
* Missing evidence reason

## Acceptance Criteria
| Criterion | Status | Evidence |

## Result
* Decision
* Overall Confidence
* User Risk
* Data Risk
* Security Risk
* Performance Risk
* Operational Risk
* SRVs
* Non-SRV Findings

## Required Changes
| Priority | Change | Reason |

## Findings
For every finding:
Severity, Title, SRV, Category, File, Location, Problem, Risk, Required Change, Evidence, Confidence.

## Verification Plan
### Happy Path
### Edge Cases
### Failure Path

## Final Recommendation
Approve, Approve With Comments, Request Changes, or Block.
```

Do not include empty finding sections.

## Jira Comment

Always output a paste-ready fenced block after the report.

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
* No Branches line.
* No `Sky Review:` prefix.
* Never use dash punctuation in Jira prose.

Severity:

* 🔴 Critical or High
* 🟡 Medium
* 🟢 Low or Optional

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

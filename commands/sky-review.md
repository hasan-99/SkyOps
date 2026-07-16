---
name: sky-review
description: Master Jira, task and PR review orchestrator for SkyOps — coordinates the review lanes into one PR-ready verdict for C#/.NET 6 changes.
user-invocable: true
disable-model-invocation: true
---

# Sky Review

You're the master review orchestrator. You coordinate review lanes rather than running one big monolithic review yourself: you build a review plan, dispatch focused specialists, aggregate their findings, validate those findings, assess risk, and generate the final report.

Every lane and the final report follow `${CLAUDE_PLUGIN_ROOT}/standards/GROUNDING.md`: findings need `file:line` evidence or they are **dropped**; no hedging; unverifiable checks are `INSUFFICIENT EVIDENCE` and block an Approve.

---

# Required Skills

* review-standards
* sky-api
* sky-service
* sky-data
* sky-security
* sky-performance
* sky-risk
* sky-evidence
* sky-verification
* sky-decision

---

# Mission

Determine:

1. Does the implementation satisfy the requirement?
2. Does it introduce risk?
3. Does it violate official standards?
4. What must change before approval?
5. What should be verified before release?

---

# Technology Constraints

Assume:

* .NET 6
* C# 10

Never recommend:

* framework upgrades
* language upgrades
* large rewrites

Review within repository standards.

---

# Parallel Review Strategy

Never review everything at once. Break the work into lanes and run only the ones that are relevant.

This is real parallelism, not sequential lanes pretending to be parallel. Spawn one subagent per selected lane by sending all the Agent tool calls in a SINGLE message so they run concurrently. Use the general-purpose agent type. Then aggregate and de-duplicate their findings.

Possible lanes:

* API
* Service
* Data
* Security
* Performance

Each lane subagent receives only:

* task summary
* Jira summary
* acceptance criteria
* changed files
* relevant diff
* the full text of the SRV catalogue so it can classify against standards

Each lane returns structured findings: severity, category, an SRV code or "not catalogued", file and line, a problem snippet with inline arrows, a short why, a fix snippet, evidence, and confidence.

Never send unrelated files. Never load the entire repository.

---

# Review Flow

**Phase 0 — Recall prior lessons.**

If `.skyops/knowledge/` exists, run `/sky-recall` first so known fixes, repo patterns, and SRV gotchas for this area surface before you review — don't re-derive what a past session already learned. Skip silently if there's no store yet.

**Phase 1 — Understand the requirement.**

Produce a Requirement Summary that answers:

* What should change?
* What should remain unchanged?
* What user flow changes?
* What data flow changes?
* What API flow changes?

---

**Phase 2 — Determine scope.**

Inspect:

```
git status --short
git diff --name-only
git diff --stat
```

Review only the touched files.

---

**Phase 3 — Select lanes and build evidence.**

Run only the relevant lanes. Build the affected project(s) and run the affected tests. Record pass, fail, and skip counts and any error output. A review without a build and test result is incomplete.

---

**Phase 4 — Dispatch lanes in parallel and collect findings.**

Spawn one subagent per selected lane, all in a single message, so they run concurrently (general-purpose agent type). Give each the context listed in Parallel Review Strategy, including the SRV catalogue. Aggregate the returned findings and de-duplicate by file and line, keeping the highest severity on conflict.

---

**Phase 5 — Classify findings.**

Use `review-standards`.

---

**Phase 6 — Validate findings.**

Use `sky-evidence`.

Every finding must contain a file, a location, and evidence. No evidence, no finding.

---

**Phase 7 — Assess risk.**

Use `sky-risk` to determine:

* User Risk
* Data Risk
* Security Risk
* Performance Risk
* Operational Risk

Return one of:

* Low
* Medium
* High
* Critical

---

**Phase 8 — Generate a verification plan.**

Use `sky-verification` to return:

* happy path
* edge case
* failure path

---

**Phase 9 — Generate a recommendation.**

Use `sky-decision`.

Possible results:

* Approve
* Approve With Comments
* Request Changes
* Block

---

**Phase 10 — Route the repair.**

Don't stop at a verdict — point each required change at the command that fixes it, so the report is actionable:

* Single reviewer/PR comment to resolve → `/sky-comment-triage`
* A bug to root-cause → `/sky-debug` (or `/sky-investigate` for backend/SQL/data/incident depth)
* "Does it actually work / is it wired?" → `sky-verification`
* A fork with 2+ real options → `sky-decision`
* Plan a multi-step change → `/sky-task` (`/sky-fast` for small)

Map each Required Change to its route in the output. Don't invent work — route only what the findings justify.

---

# Token Optimization Rules

Read:

* changed files first
* surrounding code only if needed

Never:

* review entire folders
* review entire projects
* review entire solutions

Read standards only after findings exist.

Read:

`${CLAUDE_PLUGIN_ROOT}/standards/SRV-CATALOG.md`

first.

Then only matching SRV files in `${CLAUDE_PLUGIN_ROOT}/standards/`.

---

# Output Format

# Sky Review Report

## Requirement Understanding

* Task
* Expected Change
* Impacted Flow
* Assumptions

## Review Execution

| Lane | Status | Notes |
| ---- | ------ | ----- |

## Result

* Decision
* Risk
* SRVs
* Non-SRV Findings

## Required Changes

| Priority | Change | Reason | Route |
| -------- | ------ | ------ | ----- |

## Findings

For every finding:

* Severity
* SRV
* File
* Location
* Problem
* Risk
* Required Change
* Evidence
* Confidence

## Verification Plan

### Happy Path

### Edge Cases

### Failure Path

## Final Recommendation

Approve

Approve With Comments

Request Changes

Block

Provide concise justification.

---

# Jira Comment (paste ready)

After the report, always output a fenced block the user can paste straight into the Jira ticket.

Rules:

* Line one: the ticket key and short title.
* Line two: the verdict in bold plus one sentence. If nothing blocks, say so plainly.
* One entry per finding, most severe first. Do not invent findings. If the code is clean, keep it short and say it is clean.
* No dash punctuation in prose. Use colons and short sentences. Ticket keys, SRV codes, branch names, and code stay as is.

Severity dot: 🔴 Critical or High, 🟡 Medium, 🟢 Low or Optional.

Per finding layout:

```
🔴 <SRV code or short category>: <short title>
File: <repo relative path> (line N)
SRV: <SRV code and title, or "not catalogued">

<problem code block, inline // <- arrows on the offending lines>

<one or two plain sentences: why it is wrong and the risk>

Fix:

<corrected code block>

<optional one line note>
```

Close with a release gate line for any acceptance criterion that needs manual or live verification.

---

# Review Philosophy

Signal over noise. Evidence over opinion. Risk over style. Correctness over preference.

Never report speculative findings. Never report findings without proof.

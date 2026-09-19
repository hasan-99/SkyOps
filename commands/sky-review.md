---
name: sky-review
description: Master Jira and code review orchestrator. Reads Jira context, resolves exact ticket scope, starts build and tests in the background, dispatches specialist review agents in parallel, validates end-to-end flow, and produces a short paste-ready Jira review.
user-invocable: true
disable-model-invocation: true
---

# Sky Review

You are the master review orchestrator.

Do not perform a monolithic review.
Do not launch every specialist by default.

Your job is to coordinate the review and keep context small.

## Components

Orchestration skills, always used, in order:

* `sky-review-context`
* `sky-review-scope`
* `sky-review-flow`
* `sky-review-finalize`

Review lanes. These are **agents**, not skills. Dispatch them with the Agent tool using these exact names:

* `sky-review-api`
* `sky-review-service`
* `sky-review-data`
* `sky-review-security` — selected by surface
* `sky-review-performance` — selected by surface
* `sky-srv-standards` — **mandatory, always dispatched**

Evidence and decision skills:

* `review-standards`
* `sky-evidence`
* `sky-risk`
* `sky-verification`
* `sky-decision`

Never dispatch `sky-api`, `sky-service`, `sky-data`, `sky-security`, or `sky-performance` from this
command. Those are planning skills for `/sky-task`; they are not review lanes and are not invocable here.

## Standards Catalogue

Single source of truth:

```
C:\SharedProjects\SkyOps\standards
```

It holds `SRV-CATALOG.md` and the `SRV-*.md` files. Pass this exact path to every lane you dispatch.

Never use `~/.claude/standards` — that copy is stale and incomplete. Never let a lane discover the
path by searching. A sweep against the wrong catalogue reports coverage it did not have.

## Mission

Determine:

1. Does the implementation satisfy the Jira requirement?
2. Does it preserve behavior that should remain unchanged?
3. Does it introduce correctness, data, security, performance, or operational risk?
4. Does it violate an official SRV standard?
5. Does the full changed flow work end to end?
6. What must change before approval?

## Technology Constraints

Assume .NET 6 and C# 10.

Do not recommend framework upgrades, language upgrades, or large rewrites unless the Jira requirement explicitly requires them.

Review the ticket change, not the whole codebase.

## Review Flow

### 1. Gather Context

Use `sky-review-context`.

Return:

* Jira summary
* description
* code-verifiable acceptance criteria
* relevant parent context
* all relevant comments
* resolved repositories
* resolved branches
* assumptions

Do not start code review until branch and repository scope is resolved.

### 2. Build Ticket Scope

**Reuse a scope manifest if one is current.** If `.skyops/scope/<key>.scope.md` exists and its
`head_sha` matches `HEAD`, take the changed files, symbols, affected projects and candidate
SRVs from it instead of rediscovering them. If the sha differs or the file is absent, say so
in one line and scope normally — never reason from a stale manifest.

Use `sky-review-scope`.

Return:

* ticket-tagged commits
* dependency commits only when justified
* changed files
* changed methods/classes
* relevant one-hop dependency context
* affected tests
* compact flow map

Do not use a whole branch-vs-master diff as the primary scope.

### 3. Start Build and Tests — In The Background

Start this the moment scope is resolved, and do not wait for it.

* Build the smallest affected project or solution scope.
* Run affected tests.
* Redirect output to a log and read the real exit code. Never judge a build, lint, or test result
  from a piped command — a pipe returns the last command's exit code, not the build's.
* Do not block lane dispatch on this. Step 4 and step 5 run while it is still going.

Record one of:

* Passed
* Failed - implementation
* Not Run - environment
* Not Run - tooling
* Not Run - no relevant automated tests

Environment failures are not implementation failures.

### 4. Plan Specialist Lanes

Use `sky-srv-select` to shortlist the SRVs this change can plausibly reach, and pass that
shortlist to the lanes so each checks the relevant standards closely. This is a focusing aid
only — `sky-srv-standards` still sweeps the full catalogue on every review, and a shortlisted
code is never itself a finding.

Gate the lanes deterministically from the changed file list — no model call, no repo read:

```bash
node "C:/SharedProjects/SkyOps/scripts/lane-gate.js" --scope .skyops/scope/<key>.scope.md
# or pipe the paths:  git diff --name-only <base>...HEAD | node ".../lane-gate.js"
```

It returns the required lanes and, for each skipped one, the reason. Selecting lanes by
judgement drifts run to run; this makes the same decision reproducible and costs nothing.

The gate is **asymmetric on purpose**, and you must preserve that:

* You may **add** a lane the gate skipped — say why in one line.
* You may **never drop** a lane the gate required.
* Ambiguity includes a lane. A skipped lane must always carry its stated reason into the report.

Available lanes: `sky-review-api`, `sky-review-service`, `sky-review-data`,
`sky-review-security`, `sky-review-performance`.

`sky-srv-standards` is not part of this selection. It always runs.

### 5. Dispatch Every Lane In Parallel

Dispatch all selected surface lanes **and** `sky-srv-standards` concurrently, in a single message,
while the build and tests from step 3 are still running.

Each lane receives only:

* relevant requirement summary
* relevant acceptance criteria
* relevant changed hunks
* required one-hop context
* the standards path `C:\SharedProjects\SkyOps\standards`
* the relevant SRV subset for that lane
* repo path, branch, and ticket commit

Do not send the full repository to any lane. Do not send the full SRV catalogue to a surface lane —
`sky-srv-standards` is the one lane that reads the whole catalogue, because sweeping it is its job.

### 6. Join The Build And Test Result

Before aggregating, collect the background build and test result and read its exit code.

Never finalize on an unjoined or assumed build result. If it is still running, wait for it here.

If it could not run, record the reason, lower overall confidence, and treat it as missing evidence —
not as an implementation failure.

### 7. Aggregate

Merge duplicate findings.

Keep the strongest justified severity and clearest evidence.

Do not count the same defect twice.

### 8. Cross-Flow Review

Use `sky-review-flow`.

Verify the changed behavior end to end across touched layers.

This is mandatory when the ticket crosses more than one architectural component.

### 9. Validate Findings

Use `sky-evidence` and `review-standards`.

`review-standards` classifies findings that already exist. It never substitutes for the
`sky-srv-standards` sweep. If the sweep did not run, the review is incomplete — rerun it.

Every final finding must have:

* severity
* category
* existing SRV code or `not catalogued`
* file
* narrow location
* offending behavior
* risk
* required change
* evidence
* confidence

Drop findings that are:

* speculative
* unsupported
* unrelated legacy defects
* style preference only
* outside ticket scope without a demonstrated regression

### 10. Risk and Verification

Use `sky-risk` and `sky-verification`.

Rate internally:

* User
* Data
* Security
* Performance
* Operational

Plan internally:

* Happy Path
* Edge Cases
* Failure Path

Surface only what is material: a real risk, or an acceptance criterion the code could not verify.
Do not print a risk matrix or a verification plan that says nothing.

Never claim live or manual verification.

### 11. Finalize

Use `sky-review-finalize`.

Return:

1. The short review result
2. A short paste-ready Jira comment

### 12. Capture

After the report, run `/sky-learn` for the findings that **survived step 9 validation** — the
ones with real `file:line` proof. Those are the highest-quality lessons the framework
produces: already classified against an SRV, already grounded in evidence.

Capture confirmed findings only. Never capture a lane's hunch, a dropped finding, or anything
marked `INSUFFICIENT EVIDENCE`. If a finding matches an existing lesson, `/sky-learn`
increments its `hits` instead of adding a duplicate — that recurrence count is what later
justifies promoting it into a guard.

Capture is silent bookkeeping: one line per lesson, after the report, never inside it. It
writes only to the machine-local lesson store. It never commits, never posts, never touches
the repo.

## Output

Keep the result short and clear. Show only:

* Verdict
* Acceptance criteria status
* Actual findings
* Build and test result
* Important verification gaps

Omit any section that has nothing in it. Never print a heading whose only content is
`No reportable findings`, `None`, or `N/A`. No lane table, no scope dump, no risk matrix, no
verification plan unless a real gap needs stating.

The report is ordered: what is done against the acceptance criteria, then findings, then a
short "what next" note. Requirement coverage leads; scope and build evidence stay compact and
subordinate.

Never post the Jira comment, commit, or push. Output the comment for the user to paste and
stop. Publishing requires explicit per-action permission, every time.

## Review Invariants

* Jira context comes before code review.
* Jira comments are part of the input.
* Explicit user branch/repo args override discovered values.
* Every involved repo must be resolved.
* Ticket-tagged commits are the primary scope anchor.
* Dependency commits require justification.
* Changed code gets enough dependency context to understand behavior.
* Build and tests start after scope and run alongside the lanes, and are joined before finalizing.
* Selected specialists run in real parallelism.
* `sky-srv-standards` runs on every review, alongside the selected lanes.
* The SRV catalogue is read from `C:\SharedProjects\SkyOps\standards`, and nowhere else.
* Specialists receive minimal relevant context.
* Cross-flow review validates composition across layers.
* No speculative findings.
* No finding without proof.
* Never invent SRV codes.
* Empty sections are omitted, never printed as empty.

## Philosophy

Signal over noise.

Evidence over opinion.

Risk over style.

Correctness over preference.

Parallelism is a tool, not a goal.

Maximum defect detection per token.

## Closing block

End the output with `sky-next`: the **Open** items (unverified checks, missing tests,
unmapped ACs, location gaps, unactioned findings — three at most) and one **Next** command.
Unverified claims come first. Omit the block only if this run genuinely leaves nothing to act
on. Naming a command there is a suggestion, never permission to run it.

---
name: sky-review
description: Master Jira, task and PR review orchestrator for SkyOps. Gathers context, dispatches focused review lanes as real parallel agents (SRV standards lane always on), aggregates and validates, and outputs a short report plus a paste ready Jira comment for C#/.NET 6 changes.
user-invocable: true
disable-model-invocation: true
---

# Sky Review

You are the master review orchestrator. You do not run one big review yourself. You gather context, dispatch focused lane agents in parallel, aggregate and validate their findings, then produce a short evidence based report and a paste ready Jira comment.

Every finding needs `file:line` proof and, where it fits, an SRV code. Follow `${CLAUDE_PLUGIN_ROOT}/standards/GROUNDING.md`: no proof, the finding is dropped; no hedging; unverifiable checks are `INSUFFICIENT EVIDENCE` and block an Approve.

---

# Inputs

A Jira key, a branch, or both. Accept a Jira URL. If the branch is not given, read it from the ticket comments.

---

# Lanes and agents

Dispatch lanes as real parallel subagents: send all the Agent tool calls in a SINGLE message so they run concurrently, then aggregate.

* `sky-srv-standards` — MANDATORY, always runs. Sweeps the diff against the whole SRV catalogue so no standard is missed.
* `sky-review-api`, `sky-review-service`, `sky-review-data`, `sky-review-security`, `sky-review-performance` — run only the ones the diff actually touches.

Give every agent: the requirement summary, the acceptance criteria, the changed files with the relevant diff, the standards folder path `${CLAUDE_PLUGIN_ROOT}/standards/`, the repo path, the branch, and the ticket commit. Never send unrelated files. Never load the whole repository.

---

# Flow

1. **Context.** Read the Jira ticket (summary, description, acceptance criteria, parent). Find the branch and repo. If `.skyops/knowledge/` exists, run `/sky-recall` first. Fetch, checkout, pull. Find the ticket tagged commits with `git log --grep=<KEY>` and review only those, do not diff against master. Build the scope with `git show <commit> --stat` and the per file diff.
2. **Evidence (mandatory).** Build the affected project(s). Run the affected tests. Record pass, fail, and skip counts and any error output. A review without a build and test result is incomplete.
3. **Dispatch lanes in parallel.** One message, all lane agents at once (the SRV lane plus the relevant domain lanes).
4. **Aggregate.** Merge duplicate findings by file and line, keep the highest severity on conflict. Confirm each SRV code with `review-standards`, or mark it "not catalogued" with a category. Validate with `sky-evidence`: no `file:line` proof means drop it.
5. **Judge.** Risk with `sky-risk` (User, Data, Security, Performance, Operational). Verification with `sky-verification`. Decision with `sky-decision`.
6. **Route.** Point each required change at the command that fixes it: a single reviewer comment to `/sky-comment-triage`, a bug to `/sky-debug` or `/sky-investigate`, a multi step change to `/sky-task` or `/sky-fast`. Route only what the findings justify.

---

# Required Skills

`review-standards`, `sky-risk`, `sky-evidence`, `sky-verification`, `sky-decision`. The lane agents own the per lane depth (api, service, data, security, performance) and `sky-srv-standards` owns the catalogue sweep.

---

# Technology Constraints

.NET 6 and C# 10. Never recommend framework upgrades, language upgrades, or large rewrites. Review within repository standards.

---

# Output Format

Keep it short and high signal. Lead with the verdict, then the findings with their fix, then the paste ready Jira comment. Do not pad. No long narrative sections.

# Sky Review Report

**Verdict:** Approve, Approve With Comments, Request Changes, or Block. One sentence why.

**Risk:** one line, the highest risks only.

**Evidence:** build result and test counts in one line.

## Findings

Most severe first. Only real, proven issues. Keep each finding to four short lines:

* <severity dot 🔴 🟡 🟢> <SRV code or not catalogued>: one line title
* File: path (line N)
* Fix: short snippet or one sentence
* Scope: in scope, or out of scope (base or prior commit)

If there are no blocking findings, say "No blocking findings" and stop.

## Verify before release

One or two bullets only: what to check live, and any deploy or data step. Skip if nothing applies.

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

Real parallel lanes, not sequential ones pretending to be parallel. The SRV lane always runs.

Never report speculative findings. Never report findings without proof.

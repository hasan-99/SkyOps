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

Phases 1–3 are the fixed cost. Phases 5–6 are conditional: they run only when findings survive. Spend nothing judging or routing zero findings.

1. **Context.** Read the Jira ticket (summary, description, acceptance criteria, parent). Find the branch and repo. If `.skyops/knowledge/` exists, run `/sky-recall` first. Fetch, checkout, pull. Find the ticket tagged commits with `git log --grep=<KEY>` and review only those, do not diff against master. Build the scope with `git show <commit> --stat` and the per file diff.
2. **Evidence.** Build the affected project(s). Run only the affected tests. Record pass, fail, and skip counts and any error output. A review without a build and test result is incomplete. (Trivial diff exception below may skip this.)
3. **Dispatch lanes in parallel.** One message, all lane agents at once: the SRV lane plus ONLY the domain lanes the diff actually touches. Do not dispatch a domain lane for a surface the diff does not change.
4. **Aggregate + gate.** Merge duplicate findings by file and line, keep the highest severity on conflict. Confirm each SRV code with `review-standards`, or mark it "not catalogued" with a category. Validate with `sky-evidence`: no `file:line` proof means drop it. **Gate: if zero findings survive and build/tests passed, skip phases 5 and 6 entirely and emit the Case A clean output. Do not run the judge on an empty finding set.**
5. **Judge (only if findings exist).** Risk with `sky-risk` (User, Data, Security, Performance, Operational). Verification with `sky-verification`. Decision with `sky-decision`. Skip any of these that a finding set does not warrant — a single low finding does not need the full judge trio.
6. **Route (only if findings exist).** Point each required change at the command that fixes it: a single reviewer comment to `/sky-comment-triage`, a bug to `/sky-debug` or `/sky-investigate`, a multi step change to `/sky-task` or `/sky-fast`. Route only what the findings justify.

**Trivial diff fast path.** If `git show <commit> --stat` shows the change is only comments, docs, formatting, string or config constants, or a rename with no logic change, skip the parallel lanes and the judge. Do a single quick read, run build only if a compiled file changed, and emit Case A. State in one line why it was fast pathed.

---

# Required Skills

Always available: `review-standards` and `sky-evidence` (validate findings). Conditional — used only when findings exist: `sky-risk`, `sky-verification`, `sky-decision`. The lane agents own the per lane depth (api, service, data, security, performance) and `sky-srv-standards` owns the catalogue sweep.

---

# Technology Constraints

.NET 6 and C# 10. Never recommend framework upgrades, language upgrades, or large rewrites. Review within repository standards.

---

# Output Format

Length must match findings. No findings, a few lines. Findings, one short block each. Never pad. No narrative sections.

## Case A — clean (no findings)

Output ONLY this, then stop. Do not print a Findings section. Do not print a Jira comment block.

```
✅ Sky Review: <KEY> — Approve
Evidence: build <ok/fail>, tests <pass>/<fail>/<skip>.
No findings.
```

If one or two acceptance criteria still need live checking, add a single `Verify:` line. Otherwise stop.

## Case B — findings exist

Lead with the verdict line, then one block per finding. Nothing else.

```
<verdict>: <KEY> — <one sentence why>
Evidence: build <ok/fail>, tests <pass>/<fail>/<skip>.
```

Then, most severe first, one block per finding — file, reason, fix, nothing more:

```
🔴 <SRV code or not catalogued> — <short title>
File: <repo relative path> (line N)
Reason: <one or two plain sentences: what is wrong and the risk>
Fix: <one line, or a short snippet only if a sentence will not do>
```

Severity dot: 🔴 Critical or High, 🟡 Medium, 🟢 Low or Optional. Only real, proven findings. Drop anything without `file:line` proof. Mark out of scope findings with `(out of scope)` after the title.

Add a single `Verify:` line at the end only if an acceptance criterion needs live or deploy checking.

---

# Jira Comment (paste ready)

Output the paste block ONLY in Case B (findings exist). When clean, skip it entirely — the Case A lines are enough.

Rules:

* Line one: the ticket key and short title.
* Line two: the verdict in bold plus one sentence.
* One entry per finding, most severe first. Do not invent findings.
* No dash punctuation in prose. Use colons and short sentences. Ticket keys, SRV codes, branch names, and code stay as is.

Per finding layout — keep it to file, reason, fix. Include a code block only when a sentence cannot carry the fix:

```
🔴 <SRV code or short category>: <short title>
File: <repo relative path> (line N)
Reason: <one or two plain sentences: why it is wrong and the risk>
Fix: <one line, or a short corrected snippet only if needed>
```

---

# Review Philosophy

Signal over noise. Evidence over opinion. Risk over style. Correctness over preference.

Real parallel lanes, not sequential ones pretending to be parallel. The SRV lane always runs.

Never report speculative findings. Never report findings without proof.

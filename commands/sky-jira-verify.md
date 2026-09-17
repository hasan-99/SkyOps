---
name: sky-jira-verify
description: Jira requirement coverage verifier. Fetches the ticket context and valid comments, resolves the branch, then dispatches parallel subagents to check the branch changes against every Jira requirement and reports Match, Mismatch, Remaining, and Suggestions.
user-invocable: true
disable-model-invocation: false
---

# Sky Jira Verify

You verify that a branch actually covers everything a Jira ticket asks for.

You are not doing an SRV defect review (that is `sky-review`). Your job is **requirement traceability**: take every requirement in the ticket, map it to the real changes on the branch, and say which are covered, which are wrong, and which are still missing.

You gather context, build a requirement checklist, dispatch focused subagents in parallel to verify each requirement against the diff, then aggregate into one short, easy to read list.

Read-only. Never edit code, never push, never post to Jira unless the user explicitly asks in a later message.

---

# Inputs

The user passes a Jira key, a branch name, or both. They may also point you to a branch listed in the ticket comments.

Accepted forms:

* `CLS-14321`
* a full Jira URL
* `CLS-14321 branch HJ/CLS-14321 repo CS_Datafactory_v2`
* "check the branch in the comment section"

If the branch is not given, read it from the ticket comments.

Repos live under `C:\SharedProjects`.

---

# Auto Trigger

Trigger this skill when the user asks to "verify the Jira", "re-verify my changes against the ticket", "did I cover all requirements", "check the branch against the ticket", or similar, and a Jira key or branch is in play. When only a diff is in play with no ticket, use `sky-review` or `sky-verification` instead.

---

# Mission

For the ticket, answer four things and nothing else:

1. **Match**: requirements the branch fully covers, with evidence.
2. **Mismatch**: requirements the branch touches but implements wrong or partially or in a way that diverges from what the ticket asked.
3. **Remaining / Missing**: requirements with no matching change on the branch.
4. **Suggestions**: small, optional improvements or gaps worth confirming before closing the ticket.

---

# Technology Constraints

Assume .NET 6 and C# 10. SQL Server 2016 compatible SQL for any read-only check.

Never recommend framework upgrades, language upgrades, or large rewrites. Verify within repository standards.

---

# Flow

## Phase 0. Gather context (you, the orchestrator)

1. Read the Jira ticket with the Atlassian tools. Capture summary, description, acceptance criteria, parent, and linked tickets.
2. Read the ticket **comments**. Treat comments as first class requirements: a valid comment can add, narrow, or change a requirement (for example "also handle the null case", "scope changed to internal analysts only"). Fold every still valid comment into the requirement set. Ignore comments that were later reversed or that are pure chatter.
3. Resolve the branch and every involved repo from the ticket comments first (look for a "Branches for review" comment), then from args. A ticket often names more than one repo. Resolve and verify all of them.
4. The branch name in a comment may be written without its prefix. If `origin/<name>` is not found, search `git branch -a | grep -i <KEY>` and use the real branch (commonly prefixed, e.g. `HJ/<KEY>`). If the branch was deleted after merge, fall back to the ticket tagged commits.
5. In each repo, fetch and checkout the branch (or the tagged commits) so the changes are visible in Visual Studio. Pull latest.
6. Find the ticket tagged commits: `git log --grep=<KEY>`. Build the scope from those commits only: `git show <commit> --stat` and the per file diff for each source file. Do not diff against master.

## Phase 1. Build the requirement checklist

Turn the ticket into a flat, numbered list of concrete, testable requirements. Pull from, in this order: acceptance criteria, description, then valid comments.

Each requirement is one line: an id, a short statement, and its source (AC, description, or comment).

Keep them atomic. Split "add the flag and expose it in the response" into two requirements. This list is the spine of the whole verification.

## Phase 2. Scope the changes

List the changed files and the exact diff for each ticket commit. Read surrounding code only where a requirement check needs it. Never load whole folders or projects.

## Phase 3. Dispatch verification subagents IN PARALLEL

This must be real parallelism, not sequential.

Group the requirements into a small number of lanes (by area or by repo, aim for 2 to 5 lanes). Spawn one subagent per lane by sending all the Agent tool calls in a SINGLE message so they run concurrently. Use the general-purpose agent type.

Each subagent receives only:

* the requirement summary and the subset of numbered requirements for its lane
* the list of changed files and the relevant diff
* the repo path so it can read the changed files it needs

Each subagent returns, per requirement, a verdict object:

* `req id`
* `verdict`: Match, Mismatch, or Missing
* `evidence`: file and line, or a short code snippet, that proves the verdict. Missing means no evidence found after looking.
* `note`: one plain sentence on why, and for Mismatch what differs from the requirement
* `confidence`: High, Medium, or Low

Tell every lane: verdict must be backed by the actual diff or file, no guessing. If a requirement cannot be verified from code alone (pure manual or live check), mark it `Missing` with a note "not verifiable from code" rather than assuming it passed. Signal over noise.

## Phase 4. Aggregate

Collect all lane verdicts. Every requirement id from Phase 1 must have exactly one final verdict. If two lanes disagree, keep the worse verdict (Mismatch over Match, Missing over Mismatch) and note the conflict.

## Phase 5. Suggestions

From the diff and the gaps, list small optional improvements or points to confirm before closing. Keep it short. Do not invent findings to fill space.

---

# Output Format

Keep it simple and easy to read. Lists, not tables, not walls of text.

```markdown
# Jira Verify: <KEY> — <one line verdict>

<KEY> <ticket title>. Branch: <branch> in <repo(s)>. Requirements checked: <n>.

## ✅ Match (<count>)
- R1: <requirement> — <file:line> — <one line why>
- R2: ...

## ❌ Mismatch (<count>)
- R3: <requirement> — <file:line> — <what the code does vs what the ticket asked>

## ⏳ Remaining / Missing (<count>)
- R4: <requirement> — no change found on the branch
- R5: <requirement> — not verifiable from code, confirm manually

## 💡 Suggestions (<count>)
- <small optional improvement or thing to confirm>

## Verdict
<All requirements covered | Gaps remain | Changes needed> — <one short sentence>.
```

Rules for the output:

* Every requirement from the checklist appears in exactly one of the first three sections.
* Sort each section by requirement id.
* If a section is empty, keep the header and write `- none`.
* One line verdict at the top mirrors the Verdict section: "All requirements covered", "Gaps remain", or "Changes needed".
* Never use em dashes or en dashes or arrows in prose. Use short sentences and colons. Keep code, keys, branch names, and paths as is.

---

# Optional Jira comment (only if the user asks to post)

Do not post anything to Jira on your own. If, in a later message, the user asks for a paste ready comment or asks you to post it, produce a fenced block in Jira comment style:

* Structured markdown: `###` headers, bullet lists, inline code.
* No em or en dashes, no arrows.
* Do not mention behind Dev, merge status, or local build blockers.
* Do not include "verified live on Dev", manual, or release gate lines. Report only what is verified from the code on the branch.
* Lead line: `<KEY> — <verdict word>` (Covered, Gaps, or Changes Needed), then one plain sentence, then the Match, Mismatch, and Remaining lists.

Only post with explicit per action permission.

---

# Philosophy

Every requirement gets a verdict. Every verdict gets evidence.

Missing is a valid, important answer. Do not mark something Match to be tidy.

Real parallel lanes, not sequential ones pretending to be parallel.

No verdict without proof from the actual branch.

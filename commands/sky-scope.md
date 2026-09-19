---
name: sky-scope
description: Reads the branch diff once and writes a reusable scope manifest — changed files, changed symbols, affected projects, covering tests, Jira requirements, and candidate SRVs. /sky-review, /sky-test, /sky-pr, /sky-task and /sky-jira-verify then reuse that manifest instead of each rediscovering the same diff. The single biggest token saver in the framework. Read-only.
user-invocable: true
disable-model-invocation: false
---

# /sky-scope

You are Sky Scope — the one command that reads the diff, so the other five don't have to.

Today `/sky-review`, `/sky-test`, `/sky-pr`, `/sky-task` and `/sky-jira-verify` each resolve the
branch, list changed files, work out which projects are affected and which tests cover them.
Run two of them on one ticket and you have paid for that discovery twice. Run four and the
duplicated reads dominate the session.

This command does it once and writes the answer down.

## The manifest

Written to `.skyops/scope/<branch-or-key>.scope.md` in the working repo, or to
`$SKYOPS_SCOPE_DIR` if set. It is a **cache, not a source of truth** — see Staleness.

```markdown
---
key: CLS-15368            # Jira key, else a branch slug
branch: HJ/alerts-pill
base: origin/Dev
head_sha: <sha at capture time>
captured: <ISO timestamp>
repos: [CS_Datafactory_v2, ModelUtil_Core]
---

## Changed files
- <path> (+adds/-dels) — <one-line what changed>

## Changed symbols
- <file>: <class.method> — added | modified | removed

## Affected projects
- <csproj/package and why it is in scope>

## Covering tests
- <test file/class> covers <symbol> — existing | missing

## Requirements (if a Jira key resolved)
- <AC id>: <one line> — where it is implemented, or "not found"

## Candidate SRVs
- <SRV code> — why this diff plausibly touches it (async, culture, persistence, ...)

## Not in scope
- <changes on the branch that belong to another ticket, and why>
```

## Relationship to `sky-review-scope`

These are layered, not parallel. `sky-review-scope` is the internal builder that resolves a
Jira ticket's exact code scope from tagged commits; `/sky-scope` calls it for the
requirements and ticket-scoping half, then persists the whole thing as a manifest other
commands can reuse. Do not run both independently and do not reimplement its logic here — the
point of this command is that the work happens **once**.

## Flow

1. **Resolve the branch and base.** Never trust a pull or merge message — confirm with
   `git rev-list --left-right --count <base>...HEAD`. Record the real `head_sha`.
2. **Read the diff once.** `--name-only` and `--stat` first; open a file only when the change
   is not obvious from the stat. Never pull a whole diff into context.
3. **Derive symbols, projects, tests, SRV candidates.** Candidate SRVs are a *shortlist for a
   reviewer to check*, never a finding — a candidate is not a violation.
4. **Resolve requirements** only if a Jira key is in the branch or was passed.
5. **Write the manifest** and report its path plus a 3-line summary. Do not paste the manifest.

## Staleness — the rule that keeps this safe

A cache that silently goes stale is worse than no cache. Any consumer must re-check
`head_sha` against the current `HEAD` before trusting a manifest:

* **Same sha** → use it.
* **Different sha** → say so in one line and re-run the scope. Never reason from a stale manifest.
* **Missing manifest** → fall back to normal discovery. Consumers must work without this.

Uncommitted working-tree changes are not in `head_sha`. If the tree is dirty, record that in
the manifest and treat the scope as provisional.

## Boundaries

Read-only against the code. It writes exactly one manifest file and nothing else. Never
commits, never pushes, never edits source.

## Tone

Terse. The manifest is the deliverable; the chat summary is three lines.

## Closing block

End the output with `sky-next`: the **Open** items (unverified checks, missing tests,
unmapped ACs, location gaps, unactioned findings — three at most) and one **Next** command.
Unverified claims come first. Omit the block only if this run genuinely leaves nothing to act
on. Naming a command there is a suggestion, never permission to run it.

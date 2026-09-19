---
name: sky-learn
description: Save a reusable lesson so the next session benefits — a fix that worked, a recurring bug pattern, an SRV gotcha, or a team/repo preference. Fires automatically at the end of /sky-review, /sky-debug, /sky-comment-triage and /sky-task for every CONFIRMED finding, and on request ("remember this", "save this", "note for next time"). Writes only to the machine-local lesson store — never to source code.
user-invocable: true
disable-model-invocation: false
---

# /sky-learn

You are Sky Learn — the memory writer. You turn a solved problem into a lesson a future
session can use, so the same defect is never re-derived from scratch.

This codebase targets **.NET 6 (C# 10)**.

## The store

**Machine-local**, not in any repo:

```
~/.claude/skyops-knowledge/
  INDEX.md        # generated — never edit by hand
  index.json      # generated — read by the recall hook
  lessons/
    <id>.md       # one file per lesson
```

Override with `$SKYOPS_KNOWLEDGE_DIR`.

It lives outside every repo on purpose. Lessons carry client repo internals — handler
names, table names, file paths — and the SkyOps repo is published. Sharing a lesson with a
team repo is a separate, deliberate act: `/sky-lesson-export`.

## Capture rule: confirmed only

Save a lesson only when the finding **survived validation**. That means:

* a `/sky-review` finding that passed the validation step (has `file:line` proof), or
* a `/sky-comment-triage` claim judged valid against the real code, or
* a `/sky-debug` or `/sky-investigate` root cause actually traced to its source, or
* a fix the user confirmed worked, or
* an explicit "remember this" from the user.

Never save a suspicion, a lane's unverified hunch, or a finding that was dropped for lack of
evidence. An unconfirmed lesson is worse than no lesson — it gets injected into a future
session as if it were true. **When in doubt, do not save.**

Also skip: the trivial, the one-off, anything already obvious from the codebase or git
history, and anything that only mattered to one conversation.

## Write boundary (strict)

The **only** SkyOps command that writes outside a plan file, and it writes to exactly one
place: `~/.claude/skyops-knowledge/lessons/`. Never touch source code, configs, or anything
else. Never run builds, tests, or SQL. **Never store a secret, token, connection string, or
credential value** — a lesson records *where* a credential lives, never what it is.

## Lesson format

Filename: `YYYYMMDD-<short-kebab-slug>.md`, which is also the `id`.

```markdown
---
id: 20260919-sync-io-in-alerts-handler
title: <one line, states the defect or the rule>
type: fix | pattern | srv-note | pref
srv: SRV-H-001            # the SRV code, or omit if not catalogued
repo: CS_Datafactory_v2
files:
  - src/Handlers/AlertsQueryHandler.cs:142
triggers: [alerts, handler, sync-in-async, ToList, cancellation]
source: sky-review CLS-15368
first_seen: 2026-09-19
last_seen: 2026-09-19
hits: 1
status: active
exported_to: []
---

**What:** <the defect or rule in one or two sentences.>

**Why:** <why it bites — the real consequence, not the abstract principle.>

**Fix:** <the change that resolved it, concretely. A `file:method` pointer beats a code block.>

**Apply when:** <the trigger situation next time — what a future session should look for.>
```

`triggers` is the field that makes recall work. Put in the words a future prompt would
actually contain: the error text, the table, the handler family, the SRV id, the symptom.
Five to ten is right. Generic words (`bug`, `error`, `fix`) are noise — leave them out.

## Flow

1. **Confirm it qualifies** against the capture rule above. If not, say so in one line and stop.
2. **Dedupe.** `node ~/.claude/bin/knowledge-recall.js --list` and look for a near match by
   SRV code, file, or trigger overlap.
   * **Match found** → do not add a new file. Open that lesson, increment `hits`, set
     `last_seen` to today, add the new `files:` entry and any new trigger, and sharpen the
     body if this occurrence taught something the old entry missed.
   * **No match** → create a new lesson file.
3. **Write** the lesson. Keep the body under ~10 lines.
4. **Reindex:** `node ~/.claude/bin/knowledge-recall.js --reindex`.
5. **Check for promotion** (below).
6. **Confirm** in one line: `⬢ Saved — "<title>" (<id>)`, or `⬢ Updated — "<title>" now seen 3x`.

## Promotion — the part that makes this self-learning

A store that only accumulates is a notebook. When the **same** lesson reaches `hits >= 3`,
the framework should get stricter rather than keep re-reporting it. At that point, stop and
propose exactly one of:

| Proposal | When it fits |
|---|---|
| **Implementation-time guard** | The defect is mechanically detectable while the code is being written — the `sky-async-guard` / `sky-i18n-guard` pattern. |
| **SRV candidate** | It is a real, nameable review standard the catalogue is missing. Propose it for `standards/`, flagged as a candidate — the catalogue mirrors an authoritative source, so it is never edited unilaterally. |
| **Repo rule** | It is a convention of one codebase, not a general standard. Propose a line for that repo's `CLAUDE.md`. |
| **Export to the team** | Others keep hitting it too. Propose `/sky-lesson-export`. |

Present the proposal and **stop**. Never create a guard, edit the SRV catalogue, or touch a
`CLAUDE.md` without explicit approval — promotion changes how every future session behaves,
so it is the user's call. On approval, set the lesson's `status: promoted` and record what it
became in the body.

## Token & style rules

One entry per lesson. Short body — future-you needs the point, not a transcript. A
`file:method` pointer instead of a code block. Don't reformat unrelated entries. If today's
date is unclear, ask rather than guess.

<!-- sky-next: not-applicable — this command answers a question or is an advisory guard; it implies no follow-up action. -->

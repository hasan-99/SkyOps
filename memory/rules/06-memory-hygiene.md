---
id: memory-hygiene
title: Memory — looked up, not carried
status: stable
---

# Memory — looked up, not carried

`MEMORY.md` holds counts and a lookup command, **not** the entries. Content is fetched when the work calls for it, so a session that never needs memory never pays for it.

This only works if you go and look. **Search before you start** ticket work, a debug, an unfamiliar area, or a reviewer's claim:

```bash
pwsh ~/.claude/bin/skyops-memory.ps1 find <term>   # searches active AND archived
```

Search the **archive** too — a finished ticket is the likeliest place a near-identical problem was already solved. One targeted `find` costs a few hundred tokens; re-deriving a known fact costs more, and re-deriving it wrong costs most. If nothing matches, say so and carry on.

## Categories

Durable knowledge (`environment`, `procedures`, `decisions`, `lesson`) is kept apart from temporary state (`active-ticket`). Permanent rules are not memory entries — they are this file. Completed tickets go to `archive`, which is never loaded at startup. Full contract: `C:\SharedProjects\SkyOps\memory\SCHEMA.md`.

## Update when state changes

Immediately after any of these, update the ticket's entry in the same turn — never leave it describing the previous state:

```
committed · pushed · Jira comment posted · merged · completed
assumption disproved · direction changed · a stored fact proven stale
```

Set `ticket_state` and `last_verified` to match reality. The workflow commands do this as their final step; if you got there without one, do it by hand.

## Lifecycle

```
active ticket -> completed -> extract reusable lesson -> archive ticket state
```

When a ticket reaches `done | merged | approved | no-work | completed`, run `/sky-memory archive <KEY>`. It extracts any reusable lesson into its own durable entry, then moves the ticket state out of startup memory. Nothing is deleted.

**A lesson that keeps recurring belongs in a rule, not in memory.** If the same correction has surfaced across three or more tickets, propose promoting it into `memory/rules/` — a rule is generated into `CLAUDE.md` once and costs nothing to recall, whereas a lesson must be searched for every time.

## Write discipline

One fact per entry. Keep a lesson in exactly one place — never duplicated into a ticket entry and a lesson entry. Prefer a `file:method` pointer over a pasted code block. Build listings from frontmatter with `skyops-memory.ps1`, never by reading file bodies into context.

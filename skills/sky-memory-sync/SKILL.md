---
name: sky-memory-sync
description: Update ticket memory right after a state change: committed, pushed, posted, merged, or a stored fact proven stale.
user-invocable: false
disable-model-invocation: false
---

# sky-memory-sync

The single place SkyOps updates memory after a state transition. Every workflow command ends here, so the logic lives once instead of being restated in each one.

## Fire immediately after any of these

```
changes committed · branch pushed · Jira comment posted · ticket merged
ticket completed or closed · previously uncommitted work committed
technical assumption disproved · implementation direction changed
a stored fact proven stale
```

If one of these just happened and memory still describes the previous state, memory is now actively misleading. Fix it in **the same turn**, before moving on — not "later".

## What to do

**1. Find the entry.**

```powershell
pwsh ~/.claude/bin/skyops-memory.ps1 find -Query "CLS-00000"
```

No entry and the work is substantial? Create one from `C:\SharedProjects\SkyOps\memory\templates\active-ticket.md`. Trivial one-off work needs no entry — do not manufacture memory.

**2. Rewrite the parts that changed.** Edit the body so it describes reality now: what is committed, what is pushed, what the branch is, what is actually left. Delete the superseded sentence rather than appending a contradiction — an entry that says two things is worse than one that says nothing.

**3. Re-file the frontmatter.**

```powershell
pwsh ~/.claude/bin/skyops-memory.ps1 classify -Name <entry> -TicketState <state>
```

| What just happened | `ticket_state` |
|---|---|
| work started, nothing written yet | `in-progress` |
| code done, not committed | `uncommitted` |
| committed locally, not pushed | `committed` |
| pushed / PR open / under review | `review` |
| waiting on someone or something | `blocked` |
| merged, approved, finished, or no work needed | see below |

`classify` re-stamps `last_verified` and `review_after` automatically.

**4. Completed? Hand over to the archive flow.** When the state reaches `done`, `merged`, `approved`, `no-work`, or `completed`, do **not** just mark it — run the `/sky-memory archive` lifecycle: extract any reusable lesson into its own entry first, then archive. That is what keeps startup memory from growing with every finished ticket.

**5. Was a stored fact disproved?** Correct that entry too, not only the ticket. A lesson or environment entry that has been shown wrong is the most expensive kind of stale memory — it gets trusted.

## Boundaries

- Writes **only** inside the memory store. Never touches source code, config, or the SkyOps repo.
- Updating memory is not permission to commit, push, or post. Those still need explicit per-action permission, every time.
- Never write a credential into a memory entry — record where it comes from.
- Never delete an entry. Archive it.
- `MEMORY.md` is generated; change entries and let `index` rebuild it.

## Output

One line, no ceremony:

```
⬢ memory: CLS-15379 -> committed (branch HJ/CLS-15379_alerts-export)
```

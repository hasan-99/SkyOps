# SkyOps memory

How SkyOps keeps Claude's memory useful as the number of finished tickets grows.

## The problem this solves

Claude Code's native auto-memory is a flat folder of markdown files plus a `MEMORY.md` index that is loaded into **every** session. Nothing ages out. Every completed Jira leaves its state behind, so startup memory fills with history that is no longer true — and stale state is worse than no state, because it gets trusted.

## The split

```
durable knowledge            temporary state
─────────────────            ───────────────
rules                        active-ticket
environment                  (archived when the ticket completes)
procedures
decisions
lesson
```

The rule is simple: **anything that can silently stop being true is temporary and carries a verification date; anything permanent does not.**

## Where things live

```
SkyOps repo (source of truth)          ~/.claude (generated output)
──────────────────────────────         ────────────────────────────
memory/rules/*.md            ──────►   CLAUDE.md          (always loaded)
memory/SCHEMA.md                       │
memory/templates/*.md                  │
memory/migration/*.map                 │
bin/skyops-memory.ps1        ──────►   bin/skyops-memory.ps1
commands/sky-memory.md       ──────►   commands/sky-memory.md
skills/sky-memory-sync/      ──────►   commands/sky-memory-sync.md
install.ps1                            │
                                       └► projects/<p>/memory/
                                            MEMORY.md      (generated index)
                                            *.md           (active entries)
                                            archive/
                                              ARCHIVE.md   (generated index)
                                              *.md         (completed, retrievable)
                                          skyops-secrets.local.md  (machine-local, never in the repo)
```

Nothing under `~/.claude` is source. Editing it there is undone by the next SessionStart sync.

## Permanent rules are not memory entries

Behavioural rules are not stored as recallable memory files, because recall is best-effort and a rule that only *sometimes* applies is not a rule. They live in `memory/rules/*.md`, are concatenated in filename order by `install.ps1`, and become `~/.claude/CLAUDE.md`, which is loaded into every session.

To change how Claude behaves, edit a file in `memory/rules/` and re-run the installer. Never edit `CLAUDE.md`.

## Lifecycle

```
active ticket
     │  work happens, state changes
     ▼
sky-memory-sync updates ticket_state + last_verified
     │  ticket_state reaches done | merged | approved | no-work | completed
     ▼
/sky-memory archive <KEY>
     │  1. extract reusable lessons into their own `lesson` entries
     │  2. dedupe against what is already stored
     │  3. move the entry to archive/  (moved, never deleted)
     ▼
out of MEMORY.md, still retrievable with /sky-memory find
```

The archive collapses to **one line** in `MEMORY.md` no matter how many tickets it holds. That is the property that keeps startup memory flat as the ticket count grows into the hundreds.

## Why filesystem, not a database

The store is a few dozen small markdown files. Grep is fast, git-diffable, and survives every tool in the chain. `skyops-memory.ps1` reads frontmatter only — never file bodies — so a full index costs milliseconds and zero model tokens, which is what makes it safe to run on every SessionStart. A database would add a service to keep alive and buy nothing at this size.

## Secrets

SkyOps source must never contain a credential. Machine-local secrets live in `~/.claude/skyops-secrets.local.md`, which `install.ps1` splices into the generated `CLAUDE.md` at the `{{SKYOPS_SECRETS}}` marker and never reads back into the repo. `skyops-memory.ps1 audit` reports credential-shaped content by **location only** and never prints a value.

## Commands

| | |
|---|---|
| `/sky-memory` | inspect, audit, find, classify, archive |
| `sky-memory-sync` | model-invoked; updates ticket memory after a state change |
| `skyops-memory.ps1` | the deterministic tool both of the above drive |

See `SCHEMA.md` for the frontmatter contract.

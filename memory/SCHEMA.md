# SkyOps memory schema

Every memory entry is one markdown file holding **one fact**, with YAML frontmatter. SkyOps extends Claude Code's native auto-memory frontmatter additively — the native `name`, `description`, and `metadata.type` fields keep working untouched.

```yaml
---
name: cls-15379-alerts-export              # kebab-case slug, matches the filename
description: One line. This is what recall matches on, and what the index prints.
metadata:
  node_type: memory
  type: project                            # native: user | feedback | project | reference
  category: active-ticket                  # SkyOps: see below
  status: active                           # SkyOps: active | stable | stale | archived
  ticket: CLS-15379                        # SkyOps: only for ticket entries
  ticket_state: uncommitted                # SkyOps: only for ticket entries
  last_verified: 2026-09-15                # SkyOps: only for volatile entries
  review_after: 2026-10-15                 # SkyOps: only for volatile entries
---
```

## `category` — what kind of knowledge this is

| Category | Holds | Volatile | In startup index |
|---|---|---|---|
| `rules` | permanent behavioural rules | no | no — rules live in `memory/rules/` and are generated into `CLAUDE.md` |
| `environment` | machine / tooling / network facts | slowly | yes |
| `procedures` | reusable how-to recipes | slowly | yes |
| `decisions` | project & architecture decisions | slowly | yes |
| `active-ticket` | state of a Jira currently being worked | **yes** | yes |
| `lesson` | reusable gotcha extracted from real work | no | yes |
| `archive` | completed ticket state | frozen | collapsed to one line |

## `status` — lifecycle

| Status | Meaning | Effect |
|---|---|---|
| `active` | current, being worked, expected to change | indexed; re-verify before quoting |
| `stable` | durable, no expiry expected | indexed |
| `stale` | past `review_after`, or contradicted | indexed with a `(stale)` marker; re-verify before use |
| `archived` | superseded or completed | moved to `archive/`, collapsed in the index, still greppable |

## `ticket_state` — where a Jira actually stands

Active states keep the ticket in startup memory:

```
in-progress · uncommitted · committed · review · blocked
```

Completed states make it eligible for archival:

```
done · merged · approved · no-work · completed
```

## Lifecycle fields — only where they earn their place

Add `last_verified` / `review_after` only to entries that can silently go out of date:

> Jira state · branches · commits · test counts · implementation status · local ports ·
> service behaviour · tooling quirks · environment assumptions

Do **not** add them to a permanent behavioural rule or a user preference — those do not expire, and dating them invites pointless churn.

Default review windows applied by `skyops-memory.ps1 stamp`:

| Category | `review_after` |
|---|---|
| `active-ticket` | +14 days |
| `environment` | +180 days |
| `procedures` | +180 days |
| `decisions` | none |
| `lesson` | none |

## Linking

Link related entries with `[[their-name]]`. A link to an entry that does not exist yet is fine — it marks something worth writing. `skyops-memory.ps1 audit` reports links that point at nothing, so the graph stays honest.

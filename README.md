# SkyOps

A Claude Code plugin for C#/.NET 6 backend work. Plan before you code, review what you shipped, investigate what broke, and now — catch two of the nastiest bugs *while you're still typing them*, not three weeks later in a PR comment.

This plugin is built for Claude Code. Not ported from anywhere, not shared with any other tool — this is its home.

## Install it

**Testing it locally (fastest way to try it):**

```bash
claude --plugin-dir C:\SharedProjects\SkyOps
```

That's it. Every command below shows up immediately — no marketplace needed for this.

**Installing it for real:**

```
/plugin marketplace add https://github.com/hjahouse/SkyOps.git
/plugin install skyops
```

## What's in the box

### Commands (type `/name`, or let Claude reach for them itself)

| Command | What it does |
|---|---|
| `sky-task` | Master planner — breaks a change into small specialist checks, waits for your OK before touching code |
| `sky-fast` | Same idea, quicker and lighter, for small changes |
| `sky-debug` | Traces a bug to its root cause, read-only |
| `sky-investigate` | Digs into backend/SQL/data/incident issues with parallel lanes |
| `sky-forensics` | The deep version of investigate — full incident reconstruction |
| `sky-review` | The big one — orchestrates every specialist skill below into one PR-ready verdict |
| `sky-comment-triage` | Someone left you a review comment — checks if they're actually right before you touch anything |
| `sky-pr` | Writes your PR title + description from the current diff |
| `sky-docs` | Turns a feature/flow into a Confluence-ready doc |
| `sky-explain` | Explains a piece of code like you're new to it — plain English, no jargon |
| `sky-map` | Draws the architecture map of a repo you just opened |
| `sky-doctor` / `sky-health` | Quick "is this repo/setup okay" checks |
| `status-line` | A terminal-style status readout: branch, git state, next action |
| **`sky-async-guard`** | **New.** Catches sync-I/O-inside-async bugs the moment you write them — not in review |
| **`sky-i18n-guard`** | **New.** Catches locale/timezone-dependent date parsing the moment you write it |
| **`sky-sql-destructive-guard`** | **New.** Catches destructive SQL/EF (DELETE/UPDATE with no WHERE, TRUNCATE, DROP, dropped tenant filters) the moment you write it — with the scoped safe version |
| **`sky-learn`** | **New.** Saves a reusable lesson (a fix, a pattern, an SRV gotcha) to `.skyops/knowledge/` — auto-fires when something worth remembering shows up |
| **`sky-recall`** | **New.** Surfaces those saved lessons at the start of a debug/investigate/review, so known fixes aren't re-derived |

### Skills (background specialists — `sky-review` and `sky-task` call these for you)

`sky-api`, `sky-data`, `sky-service`, `sky-security`, `sky-performance`, `sky-risk`, `sky-evidence`, `sky-decision`, `sky-verification`, `sky-change-summary`, `review-standards`.

`sky-verification` is now goal-backward: it proves a C# change is not just written but actually **wired up** (registered in DI, routed, `AddHostedService`, `DbSet` present) and not a stub — and it auto-triggers after C# edits.

### Hooks (deterministic guardrails — they run themselves)

`hooks/` holds real Claude Code hooks — safety that runs in the harness, not prompt rules the model can forget. Once the plugin is loaded they fire on every session:

| Hook | Fires on | Does |
|---|---|---|
| **sql-guard** | Bash running destructive SQL | Asks before DROP / TRUNCATE / DELETE-or-UPDATE-with-no-WHERE / `dotnet ef database drop` — shows the safe alternative |
| **git-guard** | Dangerous git | Asks before force push, push to main, `reset --hard`, `clean -f`, `branch -D`, history rewrites |
| **dotnet-format** | `.cs` edits | Reminds you to `dotnet format` + build before commit (set `SKYOPS_AUTOFORMAT=1` to auto-format the changed file) |

They **ask** rather than hard-block — an intentional op is one confirmation away — and a guard bug never blocks you (default is always allow). Details + how to disable: [`hooks/README.md`](hooks/README.md).

### Standards

`standards/` holds two things:

- **`SRV-CATALOG.md`** — the team's named list of known code-review issues (SRV-H-001 sync-in-async, SRV-H-006 locale/timezone bugs, and nine more). `sky-review` cites these by number in real PR comments instead of re-explaining the same issue every time.
- **`GROUNDING.md`** — the shared evidence law every review lane follows: cite `file:line` or the finding is dropped, no hedging, `INSUFFICIENT EVIDENCE` blocks an approve, and a deterministic severity→score rubric. Keeps findings honest and consistent across skills.

## Why the two new guard commands exist

Every other command here is read-only and runs *after* code exists — great for catching problems, less great at stopping them from happening. The SRV catalog has two High-severity entries (SRV-H-001, SRV-H-006) and nothing was catching either one while the code was actually being written. `sky-async-guard` and `sky-i18n-guard` fix that gap — they're the only two commands meant to fire mid-write, not post-hoc.

## A couple of honest notes

- This used to be **CopilotOps**, a GitHub Copilot asset library with its own install CLI. That's all gone now — see [ADR 0002](docs/decisions/0002-rename-to-skyops-claude-code-plugin.md) for why and what changed.
- This plugin only guards 2 of the catalog's 11 SRVs at implementation time so far (the 2 High-severity ones). The rest are still review-time only. More guards can follow the same pattern as `sky-async-guard`/`sky-i18n-guard` if you want fuller coverage.

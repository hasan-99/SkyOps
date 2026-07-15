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

### Skills (background specialists — `sky-review` and `sky-task` call these for you)

`sky-api`, `sky-data`, `sky-service`, `sky-security`, `sky-performance`, `sky-risk`, `sky-evidence`, `sky-decision`, `sky-verification`, `sky-change-summary`, `review-standards`.

### Standards

`standards/` holds the SRV catalog — the team's named list of known code-review issues (SRV-H-001 sync-in-async, SRV-H-006 locale/timezone bugs, and nine more). `sky-review` cites these by number in real PR comments instead of re-explaining the same issue every time.

## Why the two new guard commands exist

Every other command here is read-only and runs *after* code exists — great for catching problems, less great at stopping them from happening. The SRV catalog has two High-severity entries (SRV-H-001, SRV-H-006) and nothing was catching either one while the code was actually being written. `sky-async-guard` and `sky-i18n-guard` fix that gap — they're the only two commands meant to fire mid-write, not post-hoc.

## A couple of honest notes

- This used to be **CopilotOps**, a GitHub Copilot asset library with its own install CLI. That's all gone now — see [ADR 0002](docs/decisions/0002-rename-to-skyops-claude-code-plugin.md) for why and what changed.
- This plugin only guards 2 of the catalog's 11 SRVs at implementation time so far (the 2 High-severity ones). The rest are still review-time only. More guards can follow the same pattern as `sky-async-guard`/`sky-i18n-guard` if you want fuller coverage.

---
id: token-efficiency
title: Token, context and subagent efficiency
status: stable
---

# Token, context and subagent efficiency

Measured from this machine's transcripts: **96% of spend is cache reads, and sessions average 23.5M tokens.** The startup prompt is already nearly free. What costs money is **how large the window gets and how long the session runs** — every turn re-reads the whole thing.

So optimise the window, not the preamble.

## Keep the window small

- At ~60% context used, checkpoint: write state to the plan file or memory, then suggest `/compact`.
- Switching task = `/clear`, not `/compact`.
- Tool results are permanent. Never `cat` a big file or pipe a build/test log into context — redirect, read the exit code, `tail` the failing lines. Prefer `--name-only`, `--stat`, `head`, counts.
- Search first, read only the relevant section, don't re-read unchanged files.
- **Playwright is ~12% of spend.** Enable only when a browser check is needed; prefer `browser_find` over full snapshots; one screenshot, not one per step; compact after.

## Parallel calls ON, subagents OFF

- **Parallel tool calls: default ON.** Batch independent reads/searches/edits into one message.
- **Subagents (~13% of spend): default OFF.** Spawn only for broad fan-out search, a large file you need one slice of, isolated research, or a genuinely separable task. One well-briefed agent beats three overlapping ones. Never for trivial reads or small edits.

A subagent earns its cost through **context isolation** — what it reads never enters your window. Asking one for a full dump gives you the cost without the benefit. Brief it narrowly; take back a conclusion.

## Model tiering

Skills run on the session model and **cannot** be re-tiered. The lever is the model of any subagent you spawn: cheap models (Haiku, or Sonnet for light judgment) fetch, scan and locate; the session model judges and decides.

## Don't read what a script can tell you

For "list/summarise all the X", read the structured header only — `description:` frontmatter, an index — never the bodies. Reading every memory body once cost 170KB to produce what the headers held in ~4KB. Better, generate it: `~/.claude/bin/memories-report.sh`, `~/.claude/bin/skyops-tokens.sh`.

> In bash generators, never use `$(fn ...)` inside a loop — each fork costs ~0.5s here.

## Shell and path discipline

**Never `cd` into a deep project path for a one-off command.** Claude Code loads `CLAUDE.md` from the working directory *and every parent* — one `cd` into a frontend worktree measured **~7,000 tokens** for a single `ls | grep`. Pass the absolute path and stay shallow:

```bash
ls /c/…/deep/path/models/ | grep -i alert      # one shallow cwd
cd /c/…/deep/path && ls models/ | grep -i alert  # loads every parent
```

**Keep worktrees outside `C:\Users\hjahouse`** — anything under it re-loads the global `CLAUDE.md` as a project file. Batch independent shell work into one call.

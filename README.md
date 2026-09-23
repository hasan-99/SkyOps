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
| `sky-explain` | Turns a dense (often AI-written) Jira ticket into a simple, visual HTML brief — what's going on, what they want, and what your code flow does, grounded in the real repo |
| `sky-map` | Draws the architecture map of a repo you just opened |
| **`sky-lint`** | **New.** Reviews SkyOps itself — unwired hooks, bad frontmatter, installer gaps, hard-coded paths, drifted doc counts, version mismatches. Run before shipping a SkyOps change |
| **`sky-scope`** | **New.** Reads the branch diff once into a reusable manifest; `sky-review`, `sky-test`, `sky-pr`, `sky-task` and `sky-jira-verify` reuse it instead of each rediscovering the same diff |
| **`sky-test-gap`** | **New.** Reports what's actually untested and the minimum tests worth adding — before `sky-test` writes any |
| **`sky-verify-fix`** | **New.** Verifies one fix instead of re-running a whole review |
| **`sky-drift`** | **New.** Separates *written* from *merged* from *running* — is the fix really on Dev, and is Dev actually running it? Catches code that's correct on a branch but absent downstream |
| **`sky-test`** | **New.** Change-driven unit-test loop for CS_Datafactory_v2 — maps the diff to its tests, writes/updates them in the repo's xUnit + NSubstitute style, runs the affected ones, and commits |
| `sky-doctor` / `sky-health` | Quick "is this repo/setup okay" checks |
| `status-line` | A terminal-style status readout: branch, git state, next action |
| **`sky-async-guard`** | **New.** Catches sync-I/O-inside-async bugs the moment you write them — not in review |
| **`sky-i18n-guard`** | **New.** Catches locale/timezone-dependent date parsing the moment you write it |
| **`sky-sql-destructive-guard`** | **New.** Catches destructive SQL/EF (DELETE/UPDATE with no WHERE, TRUNCATE, DROP, dropped tenant filters) the moment you write it — with the scoped safe version |
| **`sky-learn`** | Saves a reusable lesson (a fix, a pattern, an SRV gotcha) to the machine-local store — auto-fires at the end of `sky-review`, `sky-debug`, `sky-comment-triage` and `sky-task` for **confirmed** findings only |
| **`sky-recall`** | Deliberate, wider search of those lessons. Everyday recall is automatic — see the `knowledge-recall` hook below |
| **`sky-lesson-export`** | **New.** Shares one vetted lesson from the private store into the current repo's `.skyops/knowledge/`, after a secrets/staleness gate. Opt-in, one at a time, never commits |

### Skills (background specialists — `sky-review` and `sky-task` call these for you)

**Inspection lanes (PLAN stage — `sky-task`, `sky-debug`):** `sky-api`, `sky-data`, `sky-service`, `sky-security`, `sky-performance`, `sky-verification`.

**Judgement helpers:** `sky-risk`, `sky-evidence`, `sky-decision`, `sky-change-summary`, `review-standards`, `sky-srv-select`, `sky-repo-profile`, `sky-next`.

**`sky-review` internals:** `sky-review-context`, `sky-review-scope`, `sky-review-flow`, `sky-review-finalize`.

`sky-srv-select` shortlists the SRVs a change can plausibly reach (plus the explicit exclusions) so lanes check the relevant standards closely instead of sweeping all 16 thinly — it focuses the other lanes, it never replaces the mandatory full sweep. `sky-repo-profile` establishes the facts every lane otherwise rediscovers: layout, build and single-test commands, test conventions, sibling-repo constraints.

`sky-verification` is now goal-backward: it proves a C# change is not just written but actually **wired up** (registered in DI, routed, `AddHostedService`, `DbSet` present) and not a stub — and it auto-triggers after C# edits.

### Agents (parallel subagents — `sky-review` dispatches these)

Each runs in its own context with its own model, so what a lane reads never enters yours.

| Agent | Model | Lane |
|---|---|---|
| `sky-review-api` | haiku | Routing, verbs, route templates, status codes, contracts, controller thinness (SRV-L-004) |
| `sky-review-service` | sonnet | Handler/query correctness, SOLID, async + cancellation (SRV-H-001, SRV-L-010) |
| `sky-review-data` | sonnet | Repository/query correctness, UoW boundaries (SRV-M-003), culture-sensitive persistence (SRV-H-006) |
| `sky-review-security` | sonnet | Authz/authn on the new path, injection, secrets, cross-tenant reachability |
| `sky-review-performance` | sonnet | N+1, per-item DB calls, hot paths, caching (SRV-M-007) |
| `sky-srv-standards` | sonnet | Sweeps the diff against **every** SRV, one code at a time. Always runs, never gated |
| `dotnet6-test-runner` | sonnet | Writes and runs xUnit + NSubstitute tests for changed .NET 6 code |

Which lanes run is decided deterministically — see `scripts/lane-gate.js` below.

### Scripts (invoked by commands, not hooks)

| Script | Used by | Does |
|---|---|---|
| `scripts/skyops-lint.js` | `sky-lint` | Checks SkyOps itself. `--quiet` for errors only; exit 1 on error |
| `scripts/lane-gate.js` | `sky-review` | Picks review lanes from the changed file list — no model call, no repo read. `--selftest` runs 8 cases |
| `scripts/hook-doctor.js` | run directly | Shows which hook implementation (`.js` or `.sh`) is actually active per event, and flags any guard wired twice. `--parity` diffs each `.js` against its `.sh`; `--metrics` summarises recorded hook/tool/prompt/compaction measurements (opt-in via `SKYOPS_METRICS=1`) |

### Hooks (deterministic guardrails — they run themselves)

`hooks/` holds real Claude Code hooks — safety that runs in the harness, not prompt rules the model can forget. Once the plugin is loaded they fire on every session:

One process per event: a dispatcher starts once and runs each guard in-process, instead of one spawn per guard.

| Hook | Fires on | Wired script | Does |
|---|---|---|---|
| **sql-guard** | Bash running destructive SQL | `guard-dispatch` | Asks before DROP / TRUNCATE / DELETE-or-UPDATE-with-no-WHERE / `dotnet ef database drop` — shows the safe alternative |
| **git-guard** | Dangerous git | `guard-dispatch` | Asks before force push, push to main, `reset --hard`, `clean -f`, `branch -D`, history rewrites |
| **dotnet-format** | `.cs` edits | `edit-dispatch` | Reminds you to `dotnet format` + build before commit (set `SKYOPS_AUTOFORMAT=1` to auto-format the changed file) |
| **sky-test-nudge** | C# source edits in CS_Datafactory_v2 | `edit-dispatch` | Nudges you to close the test loop with `/sky-test diff`. Silent elsewhere |
| **knowledge-recall** | every prompt | `knowledge-recall` | Scores the prompt against the lesson store and injects only strong matches. Deterministic recall — it doesn't depend on the model remembering to look |
| **session-restore** | after a compaction | `session-restore` | Points the session back at the plan file and scope manifest for the current branch. Stores nothing; silent when there is no active work |

They **ask** rather than hard-block — an intentional op is one confirmation away — and a guard bug never blocks you (default is always allow).

**Node or bash is chosen for you.** The manifest always wires the portable `.js`, so hooks work with no Git Bash. If you additionally wire a `.sh` port in your own `settings.json`, the node side detects it and stands down *for that guard*, so nothing fires twice. Measured on a Defender-scanned box: **~7.3s per node spawn against ~0.7s for bash**. Check what is actually live with `node scripts/hook-doctor.js`.

Details, env vars, and the opt-in measurement (`SKYOPS_METRICS=1`): [`hooks/README.md`](hooks/README.md).

### Standards

`standards/` holds two things:

- **`SRV-CATALOG.md`** — the team's named list of known code-review issues (16 SRVs: sync-in-async, locale/timezone bugs, NoTracking silent-no-op writes, whole-table loads, and more), mirrored from the ClearSkiesPlatform `StandardReviewViolations` source of truth. `sky-review` reads this catalog and cites SRVs by number in real PR comments instead of re-explaining the same issue every time.
- **`GROUNDING.md`** — the shared evidence law every review lane follows: cite `file:line` or the finding is dropped, no hedging, `INSUFFICIENT EVIDENCE` blocks an approve, and a deterministic severity→score rubric. Keeps findings honest and consistent across skills.

## The learning loop

Every review already produces exactly what a memory needs — an SRV-classified finding with
`file:line` proof and a fix. Until now that was thrown away at the end of each run. The loop
closes it:

```
sky-review / sky-debug / sky-comment-triage / sky-task
        │  confirmed findings only
        ▼
   /sky-learn ──────► ~/.claude/skyops-knowledge/lessons/*.md
        │                         │
        │                         ▼
        │              knowledge-recall hook  ──► injected on a matching prompt
        ▼
   hits >= 3  ──► promote: a guard, an SRV candidate, or a repo rule (asks first)
```

Four properties make it work rather than become a junk drawer:

- **Confirmed only.** A finding that failed validation never becomes a lesson. An unconfirmed
  lesson is worse than none — it gets injected into a future session as if it were true.
- **Recall is a hook, not a hope.** It scores every prompt and stays silent below the
  threshold. A recall block that fires on weak matches gets ignored, and then it's dead.
- **Recurrence is counted.** Re-hitting a lesson increments `hits` instead of adding a
  duplicate, so the store knows what keeps biting.
- **Promotion is the point.** At `hits >= 3` the framework proposes getting *stricter* —
  becoming a guard or a rule — rather than reporting the same thing a fourth time. Promotion
  always asks first; it changes how every future session behaves.

The store is machine-local and outside every repo, because lessons carry client repo
internals and this repo is published. Sharing one is a deliberate per-lesson act
(`/sky-lesson-export`), which lands an untracked file for a human to review — never a commit.

## Why the guard commands exist

Every other command here is read-only and runs *after* code exists — great for catching problems, less great at stopping them from happening. The SRV catalog has two High-severity entries (SRV-H-001, SRV-H-006) and nothing was catching either one while the code was actually being written. `sky-async-guard` and `sky-i18n-guard` fix that gap — they're the only two commands meant to fire mid-write, not post-hoc.

## A couple of honest notes

- This used to be **CopilotOps**, a GitHub Copilot asset library with its own install CLI. That's all gone now — see [ADR 0002](docs/decisions/0002-rename-to-skyops-claude-code-plugin.md) for why and what changed.
- This plugin guards **3 of the catalog's 16** SRVs at implementation time so far (`sky-async-guard`, `sky-i18n-guard`, `sky-sql-destructive-guard`). The rest are still review-time only. The learning loop is the intended way to decide which guard to write next: let recurrence counts (`knowledge-recall.js --stats`) show which SRV actually keeps biting, instead of guessing.
- The lesson store starts **empty**. Recall has nothing to return until `/sky-learn` has run a few times — the first week is capture-only, and that's expected.

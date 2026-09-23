# SkyOps Hooks

Deterministic guardrails that run in the harness — not prompt rules the model might forget. These fire automatically for **every** Claude Code session while the plugin is loaded.

`hooks.json` wires **one process per event**; a dispatcher then runs each guard in-process, so a Bash call or an edit costs a single spawn rather than one per guard.

| Event | Matcher | Wired script | Runs | What it does |
|---|---|---|---|---|
| PreToolUse | `Bash` | `guard-dispatch.js` | `sql-guard` | When a Bash command **executes** destructive SQL (DROP / TRUNCATE / DELETE or UPDATE with no WHERE / `dotnet ef database drop`) through a real runner (sqlcmd, psql, mysql, sqlite3, dotnet ef), it asks you to confirm and shows the safe alternative. Reading/grepping a `.sql` file is never flagged. |
| PreToolUse | `Bash` | `guard-dispatch.js` | `git-guard` | Asks before force pushes, pushes to main/master, `reset --hard`, `clean -f`, `branch -D`, `checkout .`, and history rewrites. `--force-with-lease` and feature-branch pushes pass. |
| PostToolUse | `Edit`/`Write`/`MultiEdit` | `edit-dispatch.js` | `dotnet-format` | On `.cs` edits, reminds you to `dotnet format` + `dotnet build` before commit. Opt-in auto-format below. |
| PostToolUse | `Edit`/`Write` | `edit-dispatch.js` | `sky-test-nudge` | After a C# **source** edit in CS_Datafactory_v2, nudges you to close the test loop with `/sky-test diff`. Silent for test files, `obj/`, `bin/`, migrations, generated code, and every other repo. Not run for `MultiEdit`, matching its original matcher. |
| UserPromptSubmit | — | `knowledge-recall.js` | — | Scores the prompt against the `/sky-learn` lesson store and injects only strong matches. Silent below threshold. |
| SessionStart | `compact` | `session-restore.js` | — | After a compaction, points the session back at the plan file and scope manifest for the current branch. **Writes nothing** and stores nothing — see below. Silent when there is no active work. |

## Surviving compaction

SkyOps already persists everything a compacted session needs, and it persists it **once**:

| State | Lives in | Written by |
|---|---|---|
| ticket key, repo, branch, base, `head_sha`, changed files, requirements | `.skyops/scope/<key>.scope.md` | `/sky-scope` |
| current phase (`Status: EXECUTING (phase N)`), Requirement Status, blast radius | `plans/<KEY>.plan.md` | `/sky-task` |

What was missing was never the state — it was the **reconnect**. Nothing deterministically told a
post-compaction session that this state existed, so it depended on the model remembering to look.
`session-restore.js` closes exactly that gap and nothing more: it creates **no checkpoint file**,
duplicates no field of the manifest, and emits about six lines of pointers.

Because it persists nothing, stale state cannot override the repo. Branch and `HEAD` are read from
live `git` at restore time, and the manifest is labelled `current` or **`STALE`** by comparing its
recorded `head_sha` against `HEAD` right then — a stale manifest tells you to re-run `/sky-scope`
rather than being quietly trusted. The hint also ends by telling the session to re-verify working
tree and build/test state itself.

It stays silent unless there is genuinely active work: no plan file *and* no manifest for the
current branch means no output at all, so ordinary conversations are untouched. Node's spawn cost
is irrelevant here — this fires once per compaction, not per prompt, which is why it has no `.sh` port.

## Design choices

- **`ask`, not hard-block.** The PreToolUse guards surface the risk and let you confirm — an intentional op is one confirmation away. They never lock you out.
- **Filtering is in the scripts, not the matcher.** The matcher is broad (`Bash`); each script decides. Robust across Claude Code versions.
- **A guard bug never blocks you.** Every script defaults to *allow* on any parse/JSON error.
- **`.js` is portable, `.sh` is fast — and selection is automatic.** `hooks.json` always wires the `.js`, because Claude Code ships Node and it works everywhere with no dependencies. Git Bash is never required. But on a Defender-scanned Windows box **node costs ~7.3s per spawn against ~0.7s for bash** (measured on the current dispatchers, 5 runs each), which for a per-prompt or per-edit hook is the difference between usable and intolerable.

  Claude Code **merges** the plugin's hooks with your `settings.json` hooks, so wiring a `.sh` port used to mean the same guard ran twice and asked twice. It no longer does: each node entry point checks `hook-env.js` for a `.sh` port wired on the same event and **stands down for that guard only**. So:

  | Git Bash wired for a guard | What runs |
  |---|---|
  | yes | the `.sh` — node stands down |
  | no | the `.js` — the portable default |

  The decision is per guard, so a half-wired setup keeps full coverage, and `dotnet-format` (which has no `.sh` port) always runs on node. Any doubt — unreadable settings, malformed JSON — falls back to **running** the node guard: a duplicate confirmation is a nuisance, a guard that silently stops guarding is not. `SKYOPS_HOOK_IMPL=node` forces node to do everything.

- **See what is actually active.** `node scripts/hook-doctor.js` prints, per event, what the plugin wires, what your settings wire, which implementation wins, and whether anything still double-fires. `--parity` additionally diffs each `.js` against its `.sh`. `install.ps1` detects Git Bash and prints the matching wiring.
- **Keep the pair in step.** A `.js`/`.sh` pair must be behaviour-identical, because whichever one is wired is the one users actually get. `sky-lint` compares the two **rule sets** and errors if they differ, naming the rules that exist on only one side. A deliberate asymmetry declares itself with a `skyops-lint: parity-exempt` comment and a reason.

> **Why rule sets and not file size:** every `.sh` here is roughly 2-3x the length of its `.js`, entirely because it hand-rolls the JSON parsing that `JSON.parse` gives the `.js` for free. Size therefore says nothing about behaviour — `git-guard`, `sql-guard` and `sky-test-nudge` were each verified to have **identical** rules and filters despite the size gap.

## Config (env vars)

| Var | Effect |
|---|---|
| `SKYOPS_AUTOFORMAT=1` | `dotnet-format.js` actually runs `dotnet format --include <file>` on the changed `.cs` file (best-effort, time-boxed) instead of only reminding. |
| `SKYOPS_HOOK_IMPL=node` | Forces the node implementation to run everything, disabling the stand-down described above. |
| `SKYOPS_METRICS=1` | Turns on measurement (off by default). See below. |
| `SKYOPS_METRICS_DIR` | Where measurements are written. Default `~/.claude/skyops-metrics/`. |

## Measurement

Off by default. `SKYOPS_METRICS=1` makes the hooks that **already run** append one JSON line per
event — it adds **no new hook spawns**, because every call site is a hook already in the pipeline.

| Recorded | Where it comes from |
|---|---|
| hook logic ms, hook process ms | measured in `guard-dispatch` / `edit-dispatch` |
| tool result bytes, tool input bytes | `PostToolUse` payload, sized and discarded |
| tool execution ms | `duration_ms`, supplied by the harness |
| slash-command name, prompt bytes | `UserPromptSubmit` — the command **name** only |
| compaction count, scope-manifest `reused`/`stale`/`absent`, open requirements | `SessionStart(compact)` |

**Never recorded:** prompt text, source, file contents, tool results, command strings, diffs, or any
conversation content. Callers pass byte counts they measured themselves — the recorder never sees a
payload — and a whitelist drops any string that is not a short identifier, so content cannot leak
through a new call site by accident.

Read it back with `node scripts/hook-doctor.js --metrics`. Overhead is ~1 µs per hook when off and
~0.5 ms when on, against a ~7,300 ms node spawn.

Two honest gaps. `proc_ms` starts at Node's own clock, so it misses the OS exec/Defender scan that
dominates a spawn — treat it as a lower bound and use an external timer for true spawn cost.
And **agent input size is not measurable**: `SubagentStart` carries only `agent_id` and `agent_type`,
so the harness never exposes a subagent's input. Measuring agent output would need a `SubagentStop`
hook, which costs one node spawn per lane (~7 s × 6 lanes on a parallel review) — deliberately not
wired.

## Turning a hook off

Remove its block from `hooks.json` (or delete the whole file to disable all hooks), then reload the plugin. Each guard is independent.

## Relationship to the guard *commands*

`sky-sql-destructive-guard` (and `sky-async-guard`, `sky-i18n-guard`) are **read-only advisory commands** you can invoke to explain a problem and show a fix. These **hooks** are the deterministic runtime gate. They complement each other: the command teaches, the hook enforces.

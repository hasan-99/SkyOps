# SkyOps Hooks

Deterministic guardrails that run in the harness — not prompt rules the model might forget. These fire automatically for **every** Claude Code session while the plugin is loaded.

| Event | Matcher | Script | What it does |
|---|---|---|---|
| PreToolUse | `Bash` | `sql-guard.js` | When a Bash command **executes** destructive SQL (DROP / TRUNCATE / DELETE or UPDATE with no WHERE / `dotnet ef database drop`) through a real runner (sqlcmd, psql, mysql, sqlite3, dotnet ef), it asks you to confirm and shows the safe alternative. Reading/grepping a `.sql` file is never flagged. |
| PreToolUse | `Bash` | `git-guard.js` | Asks before force pushes, pushes to main/master, `reset --hard`, `clean -f`, `branch -D`, `checkout .`, and history rewrites. `--force-with-lease` and feature-branch pushes pass. |
| PostToolUse | `Edit`/`Write`/`MultiEdit` | `dotnet-format.js` | On `.cs` edits, reminds you to `dotnet format` + `dotnet build` before commit. Opt-in auto-format below. |
| PostToolUse | `Edit`/`Write` | `sky-test-nudge.js` | After a C# **source** edit in CS_Datafactory_v2, nudges you to close the test loop with `/sky-test diff`. Silent for test files, `obj/`, `bin/`, migrations, generated code, and every other repo. |
| UserPromptSubmit | — | `knowledge-recall.js` | Scores the prompt against the `/sky-learn` lesson store and injects only strong matches. Silent below threshold. |

## Design choices

- **`ask`, not hard-block.** The PreToolUse guards surface the risk and let you confirm — an intentional op is one confirmation away. They never lock you out.
- **Filtering is in the scripts, not the matcher.** The matcher is broad (`Bash`); each script decides. Robust across Claude Code versions.
- **A guard bug never blocks you.** Every script defaults to *allow* on any parse/JSON error.
- **`.js` is portable, `.sh` is fast.** `hooks.json` wires the `.js` because Claude Code ships Node and it works everywhere with no dependencies. But on a Defender-scanned Windows box **node costs ~9.3s per spawn against ~1.2s for bash** (measured). For a hook that fires on every prompt or every edit, that is the difference between usable and intolerable — so where a `.sh` port exists, wire *that* one in your local `settings.json`. See `install.ps1`, which prints the wiring.
- **Keep the pair in step.** A `.js`/`.sh` pair must be behaviour-identical, because whichever one is wired is the one users actually get. `sky-lint` compares the two **rule sets** and errors if they differ, naming the rules that exist on only one side. A deliberate asymmetry declares itself with a `skyops-lint: parity-exempt` comment and a reason.

> **Why rule sets and not file size:** every `.sh` here is roughly 2-3x the length of its `.js`, entirely because it hand-rolls the JSON parsing that `JSON.parse` gives the `.js` for free. Size therefore says nothing about behaviour — `git-guard`, `sql-guard` and `sky-test-nudge` were each verified to have **identical** rules and filters despite the size gap.

## Config (env vars)

| Var | Effect |
|---|---|
| `SKYOPS_AUTOFORMAT=1` | `dotnet-format.js` actually runs `dotnet format --include <file>` on the changed `.cs` file (best-effort, time-boxed) instead of only reminding. |

## Turning a hook off

Remove its block from `hooks.json` (or delete the whole file to disable all hooks), then reload the plugin. Each guard is independent.

## Relationship to the guard *commands*

`sky-sql-destructive-guard` (and `sky-async-guard`, `sky-i18n-guard`) are **read-only advisory commands** you can invoke to explain a problem and show a fix. These **hooks** are the deterministic runtime gate. They complement each other: the command teaches, the hook enforces.

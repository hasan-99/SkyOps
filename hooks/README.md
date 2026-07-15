# SkyOps Hooks

Deterministic guardrails that run in the harness — not prompt rules the model might forget. These fire automatically for **every** Claude Code session while the plugin is loaded.

| Event | Matcher | Script | What it does |
|---|---|---|---|
| PreToolUse | `Bash` | `sql-guard.js` | When a Bash command **executes** destructive SQL (DROP / TRUNCATE / DELETE or UPDATE with no WHERE / `dotnet ef database drop`) through a real runner (sqlcmd, psql, mysql, sqlite3, dotnet ef), it asks you to confirm and shows the safe alternative. Reading/grepping a `.sql` file is never flagged. |
| PreToolUse | `Bash` | `git-guard.js` | Asks before force pushes, pushes to main/master, `reset --hard`, `clean -f`, `branch -D`, `checkout .`, and history rewrites. `--force-with-lease` and feature-branch pushes pass. |
| PostToolUse | `Edit`/`Write`/`MultiEdit` | `dotnet-format.js` | On `.cs` edits, reminds you to `dotnet format` + `dotnet build` before commit. Opt-in auto-format below. |

## Design choices

- **`ask`, not hard-block.** The PreToolUse guards surface the risk and let you confirm — an intentional op is one confirmation away. They never lock you out.
- **Filtering is in the scripts, not the matcher.** The matcher is broad (`Bash`); each script decides. Robust across Claude Code versions.
- **A guard bug never blocks you.** Every script defaults to *allow* on any parse/JSON error.
- **Node only.** Claude Code ships Node, so `node ${CLAUDE_PLUGIN_ROOT}/hooks/*.js` works cross-platform (Windows/macOS/Linux). No extra dependencies.

## Config (env vars)

| Var | Effect |
|---|---|
| `SKYOPS_AUTOFORMAT=1` | `dotnet-format.js` actually runs `dotnet format --include <file>` on the changed `.cs` file (best-effort, time-boxed) instead of only reminding. |

## Turning a hook off

Remove its block from `hooks.json` (or delete the whole file to disable all hooks), then reload the plugin. Each guard is independent.

## Relationship to the guard *commands*

`sky-sql-destructive-guard` (and `sky-async-guard`, `sky-i18n-guard`) are **read-only advisory commands** you can invoke to explain a problem and show a fix. These **hooks** are the deterministic runtime gate. They complement each other: the command teaches, the hook enforces.

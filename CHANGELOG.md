# Changelog

All notable changes to SkyOps (formerly CopilotOps) should be documented here.

SkyOps follows semantic versioning:

- `PATCH` version, like `2.0.1`, for fixes, typos, docs, or small safe wording clarifications.
- `MINOR` version, like `2.1.0`, for new commands, new skills, or backward-compatible improvements.
- `MAJOR` version, like `3.0.0`, for breaking changes, folder structure changes, removed commands, or changed safety behavior.

## [2.7.0] - Guards wired, broken lanes fixed, context hygiene

Driven by a framework audit plus real usage telemetry. The telemetry was the surprise:
**86% of token spend happens in sessions already above 150k context**, and the rule packs
cost ~12% — so context size outranks asset overhead by roughly seven to one. Priorities
were reordered accordingly.

### Fixed

- **The destructive-action guards were never running.** `bin/sky-guard.sh` (the bash port of `git-guard.js` + `sql-guard.js`) existed in the repo but was referenced nowhere in `settings.json`, and `hooks/hooks.json` only applies in plugin mode, which is not how SkyOps is installed. Every "ask before destructive" rule rested on model compliance alone. Now wired as `PreToolUse: Bash` and verified against force-push, reset --hard, DELETE-without-WHERE, and two negative cases.
- **The five PLAN-stage specialist lanes could not be invoked.** `sky-api`, `sky-service`, `sky-data`, `sky-security`, `sky-performance` all carried `disable-model-invocation: true` while `sky-workflow-task` and `sky-workflow-debug` instructed the model to dispatch them. They silently did nothing. Replaced by real agents (below).
- **`sky-review` pointed at the wrong specialists** — it listed the five *planning* skills instead of its own `sky-review-*` agents.
- **The memory reindex targeted whichever store the cwd resolved to**, so sessions started from different directories indexed different stores and they drifted. `install.ps1` now indexes every SkyOps-managed store explicitly.

### Added

- `sky-plan-api`, `sky-plan-service`, `sky-plan-data`, `sky-plan-security`, `sky-plan-performance` — the planning lanes as **agents**. As skills they ran inline and saved nothing; as agents they get context isolation and a cheap model. Skills cannot be re-tiered (see `memory/rules/11-token-efficiency.md`), so this was the only way to get both.
- `sky-jira-investigator` agent. The ticket bootstrap — description, every comment, every linked issue, every Confluence page at `detail: "full"` — is the largest single tool-output dump in a ticket. It now happens in an agent's context, and `sky-dispatch` receives the distilled requirements instead.
- `sky-db-investigator` agent. Returns the answer, not the rows. Read-only by construction.
- `bin/sky-precompact.sh` + `PreCompact` wiring. Compaction is routine at this context size, and it reliably loses operational state (pushed? which AC remain?). The hook prompts a `sky-memory-sync` before the window is discarded.
- `memory/rules/12-context-hygiene.md` — checkpoint at ~60%, large-tool-output discipline, Playwright accumulation (12% of usage), subagent discipline (13%).
- Consistency linter in `install.ps1`: catches an asset referenced but not invocable (the dead-lane bug above), a broken reference, an over-budget description, and an unwired hook script. Runs every sync; findings go to `skyops-install-warnings.txt`.
- `references/` + `~/.claude/skyops-refs/` for material a skill needs only at one moment.

### Changed

- **`sky-rules-memory` and `sky-rules-dotnet` promoted into the always-loaded rules.** Telemetry showed them at 4% and 3% of total spend despite being ~520 and ~460 tokens — only possible by loading many times per session. The load-once rule is advisory and does not hold against a trigger that fires on every C# edit. Paying ~980 tokens once beats paying 520 an unbounded number of times. `sky-rules-jira` and `sky-rules-data` stay on-demand; their triggers are genuinely occasional.
- `sky-workflow-task/SKILL.md` split 26,249 → 16,043 bytes; the plan-file template and execution engine are read only when actually needed.
- 25 model-invocable descriptions rewritten to ≤160 chars with explicit gating ("Internal lane of /sky-review. Do not invoke on its own") to stop orchestrator internals auto-firing.
- `MEMORY.md` caps the active-ticket list at the 5 most recently touched and collapses the rest to one line. 13,865 → 11,917 bytes.
- `install.ps1` gains a HEAD+dirty-tree stamp gate (unchanged repo exits in ~2s) and prunes orphaned installed assets — it previously only ever copied, so retired assets lingered forever.

### Removed

- `sky-learn` and `sky-recall` retired to `retired/`. They read and wrote `.skyops/knowledge/`, which did not exist in any repo — the learning loop had never run. Lessons go to the memory store that works.
- The five superseded planning skills, retired to `retired/` rather than deleted (one had uncommitted edits).

### Note

Nothing in this release was committed, pushed, or posted.

## [2.5.0] - Sky Review lanes are agents, mandatory SRV sweep, leaner report

### Added

- New `sky-srv-standards` agent: a dedicated SRV compliance lane that sweeps the diff against the entire SRV catalogue one code at a time, so no standard is missed. `sky-review` always dispatches it.
- New per lane review agents in `agents/`: `sky-review-api`, `sky-review-service`, `sky-review-data`, `sky-review-security`, `sky-review-performance`. Each is small, focused, and reusable on its own.

### Changed

- `sky-review` is now a thin orchestrator (301 lines down to 126). The per lane depth moved into the agents. It gathers context, dispatches the lane agents in parallel, aggregates and validates, and outputs a short report plus the paste ready Jira comment.
- The report format is trimmed to a verdict, a one line risk, a one line evidence, and findings as four short lines each (severity, file and line, fix, scope). No long narrative sections.

## [2.4.0] - Sky Review runs real parallel lanes with evidence and a paste ready Jira comment

### Changed

- `sky-review` now dispatches each selected review lane as a real parallel subagent (one Agent call per lane, sent together) instead of running the lanes sequentially. Findings are aggregated and de-duplicated by file and line.
- Added a mandatory evidence step: the review builds the affected project(s) and runs the affected tests, and records the pass, fail, and skip counts. A review without a build and test result is now incomplete.
- Each lane subagent receives the full SRV catalogue and must classify every finding against an SRV code or mark it not catalogued, keeping SRV standards checking central to the review.

### Added

- `sky-review` now ends every report with a paste ready Jira comment block, one entry per finding, using a severity dot (🔴 🟡 🟢), File, SRV, a problem snippet, a short why, and a Fix snippet. The block follows the no dash writing style.

## [2.3.0] - Sync SRV catalog with the source of truth

### Added

- Synced the SRV catalog with the authoritative `ClearSkiesPlatform/Backend/docs/StandardReviewViolations` source — added the 5 SRVs SkyOps was missing (catalog now 11 → 16):
  - **SRV-H-014** (High, Data/Persistence) — mutate-then-`SaveChanges` on an untracked entity under a NoTracking-default context (silent 0-row write).
  - **SRV-H-016** (High, Data/Persistence) — shared EF entity schema change reaches only some of the databases it's mapped to (runtime "Invalid column name"/"Unknown column").
  - **SRV-L-015** (Low, Code Clarity) — verbose, redundant comments that restate the code and repeat a narrative.
  - **SRV-M-012** (Medium, Performance) — whole-table load to find one row by a translatable key.
  - **SRV-M-013** (Medium, Performance) — server-side grid loads the whole table, then filters/sorts/pages in memory.
- Added the **Performance** section to `SRV-CATALOG.md` (its first entries) and the Performance category + new candidate SRVs to `review-standards` so classification can reach them.

### Notes

- Coverage check: `sky-review` reads `SRV-CATALOG.md`, so it now covers all 16. Implementation-time guards still exist only for SRV-H-001/L-010 (`sky-async-guard`) and SRV-H-006 (`sky-i18n-guard`); the new High SRVs (H-014, H-016) are review-time only for now — write-time guards can follow the same pattern.

## [2.2.0] - Deterministic hooks, memory store, and legacy cleanup

### Added

- **`hooks/`** — the first real Claude Code hooks, wired via `.claude-plugin/plugin.json`. Deterministic guardrails that run in the harness instead of relying on the model to remember a rule:
  - `sql-guard.js` (PreToolUse/Bash) — asks before destructive SQL executed through a real runner (DROP/TRUNCATE/DELETE-or-UPDATE-with-no-WHERE/`dotnet ef database drop`); ignores reading/grepping `.sql` files.
  - `git-guard.js` (PreToolUse/Bash) — asks before force push, push to main/master, `reset --hard`, `clean -f`, `branch -D`, `checkout .`, and history rewrites.
  - `dotnet-format.js` (PostToolUse/Edit·Write·MultiEdit) — reminds to `dotnet format` + build on `.cs` edits; opt-in auto-format via `SKYOPS_AUTOFORMAT=1`.
  - Guards use `permissionDecision: "ask"` (surface + confirm, never hard-lock) and default to *allow* on any internal error, so a hook bug can never block work. See `hooks/README.md`.

### Changed

- **Memory store hardened.** `sky-learn`/`sky-recall` now use a defined `.skyops/knowledge/` layout (`README.md`, `INDEX.md`, `fixes.md`, `patterns.md`, `srv-notes.md`, `prefs.md`), meant to be committed as *team* memory. `sky-learn` maintains `INDEX.md` and bootstraps the folder on first use; `sky-recall` reads the index first for cheap, reliable lookup. `sky-review` gained a Phase 0 that recalls prior lessons before reviewing.
- **Legacy drift fixed.** Renamed lingering "CopilotOps" references to SkyOps across `sky-fast`, `sky-map`, `sky-review`, `status-line`, and `CONTRIBUTING.md` (including a stale `C:\SharedProjects\CopilotOps` path). Rewrote `sky-health` and `sky-doctor`: they no longer health-check for the removed `.github/` Copilot-asset delivery mechanism — they now check real repo/.NET/Claude-Code readiness. `sky-doctor` keeps its new blind-3-scan Change Diagnostic Mode.
- **Fixed a dangling reference** to a non-existent `/sky-fix` command (now routes to `/sky-debug`).

## [2.1.0] - Grounding protocol, goal-backward verification, and memory

Ideas adapted from a broader Claude Code workflow framework, refit to SkyOps' .NET 6 / SQL Server 2016 / no-automated-tests reality — taking the discipline, not the stack.

### Added

- **`standards/GROUNDING.md`** — one shared evidence law referenced by the skills: cite `file:line — "quoted"` or the finding is dropped; no hedging words; `INSUFFICIENT EVIDENCE` is a fail signal, not a silent pass; a deterministic severity→score rubric aligned to the SRV catalog (High/Medium/Low/Observation); and a spawning-discipline section (model-per-node + per-lane tool budgets).
- **`sky-sql-destructive-guard`** — implementation-time guard that fires when destructive SQL/EF is being written (`DELETE`/`UPDATE` without `WHERE`, `TRUNCATE`, `DROP`, `ExecuteSqlRaw` variants, destructive migration `Down`, tenant-filter removal) and shows the scoped, safe alternative before it reaches a DB. Write-time counterpart to `sky-risk`'s new Hard Gate.
- **`sky-learn` / `sky-recall`** — the only write-capable helpers, scoped append-only to a project-local `.skyops/knowledge/` store. `sky-learn` auto-captures reusable lessons (fixes, patterns, SRV gotchas, prefs) during work; `sky-recall` surfaces them at the start of a debug/investigate/fix/review so known fixes aren't re-derived.

### Changed

- **`sky-verification`** — rebuilt around a goal-backward **3-level check** (Truth → Exists/not-a-stub → **Wired**) tuned for C#: proves new services/controllers/hosted services/EF `DbSet`s/middleware/options are actually registered and reachable (DI, routing, `AddHostedService`, `MapControllers`), with C# stub tells (`NotImplementedException`, empty `catch`, fake-async, `Task.CompletedTask`). Now auto-triggers after C# edits and on "does this work / verify this".
- **`sky-comment-triage`** — added a skeptic *refute-before-confirm* pass: a claim is only `Valid` if it survives an honest attempt to prove it wrong with evidence.
- **`sky-review`** — added a repair-routing phase (each Required Change points at the command that fixes it) and a `Route` column; findings now follow the shared grounding law.
- **`sky-evidence`, `sky-decision`, `sky-risk`** — now reference `GROUNDING.md`; `sky-risk` gained a deterministic Hard Gate for destructive patterns; `sky-decision` leads with one committed recommendation instead of a menu.
- **`sky-map`** — now also emits a compact **Machine Map (JSON)** (layers, entrypoints, DI registrations, hosted services, `DbSet`s) that `sky-verification` can consume for its wiring check.
- **`sky-doctor`** — added an optional **Change Diagnostic Mode**: three blind scans (requirement / code-diff / verification) that report where they disagree, for "the ticket says X but the code does Y" confusion.

## [2.0.0] - Rename to SkyOps, become a Claude Code plugin

### Changed

- Renamed the framework from CopilotOps to **SkyOps** and rebuilt it as a real, installable Claude Code plugin (`.claude-plugin/plugin.json` + `commands/` + `skills/` + `standards/` at the repo root), not a loose set of personal files.
- Fixed real bugs found during the migration: 3 files with malformed frontmatter, 3 files missing required frontmatter fields, and 2 files with a hardcoded personal path — now using `${CLAUDE_PLUGIN_ROOT}`.
- Full tone pass across every command/skill: same rules, plainer and warmer wording.

### Added

- `sky-async-guard` — implementation-time guard for SRV-H-001 (sync I/O inside async methods) and SRV-L-010 (missing/dropped CancellationToken). Fires while the code is being written, not just at review time.
- `sky-i18n-guard` — implementation-time guard for SRV-H-006 (culture/timezone-dependent DateTime parsing).
- `sky-comment-triage` — verifies a reviewer's comment against the code and checks for the same defect elsewhere before proposing a fix.

### Removed

- The entire GitHub Copilot delivery mechanism: `templates/.github/`, the repo's own self-referential `.github/`, and the custom Node CLI (`src/`, `bin/`, install/init/link/health/doctor/validate/rollback/codex-install) that existed solely to manage it. Claude Code installs/loads this plugin itself — no custom installer needed.
- CLI-specific docs (`ADMIN_SETUP.md`, `COMMAND_CATALOG.md`, `PRIVATE_GITHUB_INSTALL.md`, `PRIVATE_GITHUB_USER_GUIDE.html`, `TEAM_ONBOARDING.md`) — all described the now-removed install workflow.

## [1.3.0] - Replace Test Skill With Verification Workflow

### Changed

- Replaced the old `sky-tests` specialist skill with `sky-verification`.
- Updated planning and debug prompts to use the verification lane.
- Updated README command and skill reference sections.
- Kept `.github/skills` and `templates/.github/skills` aligned.

### Added

- Additional internal specialist skills for change summaries, decisions, evidence, and risk checks.
- Prompt command documentation for investigation, PR, and forensics workflows.
- HTML showcase for presenting CopilotOps workflow, parallel lanes, and token savings to the team.

## [1.2.0] - Add Private GitHub npx Install Preparation

### Added

- `copilotops install` command.
- Private GitHub repository npx install documentation.
- Validation checks for private GitHub package readiness.

### Notes

Publishing is not performed by this change. Invited users can use the private GitHub repository through npx after they have repository access and GitHub authentication.

## [1.1.0] - Add Doctor Diagnostics

### Added

- `copilotops doctor` CLI command.
- `/sky-doctor` read-only diagnostic prompt.
- Doctor checks for:
  - Node version
  - package/version consistency
  - framework file presence
  - template presence
  - target project CopilotOps integration
  - Git status
  - workflow safety
  - recommended next action

### Notes

This is a backward-compatible feature release.

## [1.0.0] - Initial Stable Internal Release

### Added

- CopilotOps Framework name and structure.
- Shared GitHub Copilot instructions.
- Shared prompt templates.
- Shared specialist skills.
- Token-saving specialist lane model.
- `APPROVE PLAN` planning safety rule.
- Command catalog.
- Team onboarding guide.
- Architecture decision record.
- Governance and prompt change policy.
- Local CLI framework structure.
- CLI commands:
  - `copilotops init`
  - `copilotops link`
  - `copilotops health`
  - `copilotops validate`
  - `copilotops rollback`
- Template folder:
  - `templates/.github/copilot-instructions.md`
  - `templates/.github/instructions`
  - `templates/.github/prompts`
  - `templates/.github/skills`

### Safety

- Planning prompts must remain read-only until the user types `APPROVE PLAN`.
- CopilotOps must be tested in one project before broad rollout.
- Project `.github/workflows` folders must not be overwritten.

### Notes

This is the first stable internal version of CopilotOps Framework.

# Changelog

All notable changes to SkyOps (formerly CopilotOps) should be documented here.

SkyOps follows semantic versioning:

- `PATCH` version, like `2.0.1`, for fixes, typos, docs, or small safe wording clarifications.
- `MINOR` version, like `2.1.0`, for new commands, new skills, or backward-compatible improvements.
- `MAJOR` version, like `3.0.0`, for breaking changes, folder structure changes, removed commands, or changed safety behavior.

## [2.9.0] - Predictable model routing without a routing framework

### Small work no longer requires agent fan-out

`/sky-fast` previously required parallel specialist agents for every task, even when one clear path
and a few files were enough. It now starts in direct mode for narrow work and dispatches only when
independent areas genuinely need separate reasoning. Parallelism is retained for real multi-lane
work; security, data, and cross-project concerns still escalate out of the cheap path.

### One Haiku locator instead of three overlapping helpers

Added `sky-reader`, a deliberately narrow read-only Haiku agent for locating files, symbols, call
sites, registrations, routes, and nearby tests. It returns bounded `file:line` facts and is forbidden
from correctness, security, architecture, EF/UoW, root-cause, performance, and Jira verdicts.
`/sky-explain`, `/sky-pr`, and sibling-pattern searches in `/sky-comment-triage` now use this named
agent where the work is mechanical. Existing `/sky-scope` and `sky-repo-profile` remain the reusable
diff and repository caches; no duplicate requirement-extractor or test-locator agents were added.

### Requirement verdicts stay on Sonnet

`/sky-jira-verify` now explicitly selects Sonnet for its general-purpose verification subagents and
uses the smallest useful lane count. Those agents interpret requirements and decide Match/Mismatch,
so they are intentionally not routed through Haiku. Existing service, data, security, performance,
SRV, and test agents remain on Sonnet; the bounded API review lane remains on Haiku. No Opus agent or
complexity-scoring router was added because SkyOps did not have an always-Opus path to correct.

## [2.8.0] - One spawn per event, automatic hook selection, and the first measurements

All timings below were measured on a Defender-scanned Windows box: **~7.27s per node spawn,
~0.71s per bash spawn** (5 runs each). The old `~9.3s / ~1.2s` and `~18s / ~1.8s` figures quoted
across `install.ps1`, `hooks/README.md` and the `.sh` headers were stale and disagreed with each
other; they are now one measured pair.

### Hooks fired one process per guard
`hooks.json` wired `sql-guard.js` + `git-guard.js` as two `PreToolUse` entries and
`dotnet-format.js` + `sky-test-nudge.js` as two `PostToolUse` entries, so every Bash call and every
edit paid two node spawns. Added `guard-dispatch.js` and `edit-dispatch.js`: one spawn per event,
each guard still owning its own rules (the dispatchers `require` them — no logic is duplicated).
Order, exit codes, stdin/stdout and the `ask` decision are unchanged; `sky-test-nudge` is still
kept off `MultiEdit`, matching its original matcher. Verified with 56 behavioural checks.

### Node and bash hooks both fired, so guards ran twice
Claude Code merges plugin hooks with `settings.json` hooks. A machine wiring the faster `.sh` ports
also ran the plugin's `.js`, so the SQL and git guards each evaluated **twice** and a dangerous
command asked for confirmation twice. Added `hook-env.js`: the node side detects a `.sh` port wired
on the same event and stands down **per guard**, so a half-wired setup keeps full coverage and
`dotnet-format` (no `.sh` port) always runs. Any doubt — unreadable settings, bad JSON — falls back
to *running* the node guard. `SKYOPS_HOOK_IMPL=node` forces node. `.js`/`.sh` parity verified by
differential test: 23 comparisons, 0 mismatches.

### No way to see which hook implementation was active
Added `scripts/hook-doctor.js`: prints, per event, what the plugin wires, what your settings wire,
which implementation wins, and flags anything that would fire twice. `--parity` diffs each `.js`
against its `.sh`. `install.ps1` now detects Git Bash and prints the matching wiring instead of
unconditional advice — its old text told users to wire `sky-test-nudge.js`, which the plugin
already wired, causing the double-fire it was meant to prevent.

### `dotnet6-test-runner` contradicted the repo's own test conventions
The agent mandated **Moq** and **FluentAssertions** and AAA section comments. `/sky-test`'s House
Rules say "No Moq/FakeItEasy", "No FluentAssertions/Shouldly — they are not referenced", and "No
`// Arrange // Act // Assert` comments". Tests written to it would not compile. Rewritten to derive
conventions from the target repo (`PackageReference` list, then nearby tests) and never introduce a
library the project lacks. 203 → 58 lines, 17 → 6 tools; `Write`/`Edit` added — it previously had
no way to create the test files it existed to write.

### Agents had no output limit
Added an **Output Budget** to `standards/GROUNDING.md` — the shared contract that, despite saying
"reference this from a skill with one line", was referenced by nothing. Max 5 findings, ~600-800
words, no raw logs, no full diffs, `CLEAN` when clean. Every Critical and High is exempt from both
limits and never dropped; anything held back by the cap must be named in a count line. Wired into
all 7 agents with one line each.

### Active work was rediscovered after every compaction
`/sky-scope` and `/sky-task` already persist key, branch, `head_sha`, phase and open requirements —
what was missing was the reconnect. Added a `SessionStart` (`compact`) hook, `session-restore.js`,
that **writes nothing** and emits ~6 lines pointing at the existing plan file and scope manifest,
marking the manifest `current` or `STALE` by comparing its `head_sha` to `HEAD` live. Silent when
there is no active work.

### Nothing was measured
Added `hooks/metrics.js` (97 lines, **off by default**, `SKYOPS_METRICS=1`). Records hook logic and
process time, tool result/input bytes, the harness-supplied `duration_ms`, slash-command name and
prompt size, compaction count, and whether the scope manifest was reused or stale. It adds **no new
hook spawns** — every call site is a hook that already runs. Overhead ~1µs off, ~0.5ms on, against a
~7,270ms spawn. Never records prompt text, source, tool results or command strings: callers pass
byte counts, and an identifier whitelist drops anything else. Verified with 9 sensitive probes, all
clean. Read it back with `hook-doctor.js --metrics`.

### Lint
`skyops-lint.js` now follows `require()` one hop out of a wired hook, so guards reached through a
dispatcher are not reported as dead.

## [2.7.0] - Framework self-checks, reusable scope, and the location axis

### Added

- New `/sky-lint` + `scripts/skyops-lint.js` — SkyOps reviewing itself: frontmatter validity and
  name/filename agreement, hooks that ship but are wired in no `hooks.json`, installer coverage
  gaps, hard-coded machine paths, README counts that have drifted from `standards/`, version
  agreement across `VERSION`/`package.json`/`CHANGELOG`, and docs pointing at generated files
  the engine no longer writes. Found 4 real issues on its first run against this repo.
- New `/sky-scope` — reads the branch diff once into a reusable manifest (changed files,
  symbols, affected projects, covering tests, requirements, candidate SRVs). `/sky-review`,
  `/sky-test`, `/sky-pr`, `/sky-task` and `/sky-jira-verify` now all check for a current
  manifest before rediscovering the same diff. Manifests are a cache: a consumer must confirm
  `head_sha` matches `HEAD` or fall back to normal discovery.
- New `/sky-test-gap` — reports what behaviour changed, what already covers it, and the minimum
  tests worth adding, ranked, before `/sky-test` writes anything. Writes nothing itself.
- New `/sky-verify-fix` — verifies one fix and its adjacent blast radius instead of re-running a
  full review. `UNVERIFIED` is a first-class verdict.
- New `/sky-drift` — separates *written* from *merged* from *running*: is the change really on
  the base branch (by content, since squash merges defeat SHA checks), are its tests there too,
  and is the environment actually running it. Deliberately does **not** re-check acceptance
  criteria — that remains `/sky-jira-verify`.
- New internal skills `sky-srv-select` (shortlists the SRVs a change can plausibly reach, plus
  explicit exclusions, so lanes check the relevant standards closely — it focuses the lanes and
  never replaces the mandatory full sweep) and `sky-repo-profile` (layout, build and single-test
  commands, test conventions, sibling-repo constraints; cached per repo).

- New `scripts/lane-gate.js` — deterministic `sky-review` lane selection from the changed file
  list alone: no model call, no repo read. `sky-review` step 4 previously chose lanes by
  judgement, which drifts run to run. The gate is **asymmetric on purpose**: the orchestrator
  may add a lane it skipped, never drop one it required, and ambiguity includes a lane. Ships
  with `--selftest` (8 cases, all passing).

- New internal skill `sky-next` — the standard closing block for every command: what is still
  **Open** (unverified checks first, then unmapped ACs, missing tests, location gaps, max three)
  and one **Next** command to type. All 27 commands now either wire it or declare
  `<!-- sky-next: not-applicable -->` with a reason, and `sky-lint` enforces that.

### Fixed

- **Duplication sweep.** The five lane *skills* (`sky-api`, `sky-data`, `sky-service`,
  `sky-security`, `sky-performance`) and the five same-topic review *agents* looked like
  duplicates but are not — the skills are PLAN-stage lanes used by `/sky-task` and `/sky-debug`,
  the agents are REVIEW-stage lanes for `/sky-review`. They were being confused because nothing
  said so; each skill description now states its stage and names its counterpart. Nothing was
  deleted: both have live callers.
- `/sky-scope` overlapped the existing `sky-review-scope` skill. They are now explicitly
  layered — `sky-review-scope` is the ticket-scope builder, `/sky-scope` calls it and persists
  the manifest — rather than two parallel paths.
- Stale product name: `sky-debug`, `sky-doctor`, `sky-fast`, `sky-health` and `sky-map` still
  said "CopilotOps" after the ADR 0002 rename. Renamed; `sky-lint` now catches it. The README's
  historical note is deliberately unchanged.
- `sky-test-nudge.js` was wired in no `hooks.json` event, so it never fired for plugin users.
  Now wired as `PostToolUse` on `Edit|Write`; verified it fires on CS_Datafactory_v2 C# source
  and stays silent for test files, `obj/`, and other repos.
- `agents/dotnet6-test-runner.md` hard-coded `C:\Users\hjahouse\...` as its memory path. Now
  resolved from the home directory at runtime.
- The `git-guard.sh`, `sql-guard.sh` and `sky-test-nudge.sh` bash ports existed only on one
  machine and were never in the repo, so `install.ps1` could not distribute them and a rebuild
  would have lost them. Now committed. Each was scanned for secrets and hard-coded user paths
  and smoke-tested (silent on benign input, `ask` on a force push / bare `DELETE`) first.

- **Hook parity is now checked by rule set, not file size.** `sky-lint` extracts the
  user-visible rule strings from each `.js`/`.sh` pair and errors if they differ, naming the
  rules present on only one side. The first version of this check compared line counts and
  was wrong: every `.sh` is 2-3x its `.js` purely because it hand-rolls the JSON parsing
  `JSON.parse` provides for free, so it reported three guards as divergent when
  `git-guard`, `sql-guard` and `sky-test-nudge` were each verified to have identical rules
  and identical filters. Verified by injecting a deliberate rule change (caught) and
  reverting (clean).

### Notes

- `/sky-agent-gate` was proposed and **not** added as a skill: `sky-review` step 4 already
  selected lanes. The real gap was that the criteria were vague LLM judgement, so the fix was
  to make the existing step deterministic (`lane-gate.js`) rather than add an orchestration
  layer on top of it.
- Model tiering was reviewed and needed no change: all 7 agents already declare a model
  (`sky-review-api` on haiku, the rest sonnet, none on opus). Commands and skills run on the
  session model and cannot be re-tiered, so lane *gating* — not model choice — is where the
  remaining saving is.
- `/sky-converge` was proposed and **not** added: `/sky-task` already maintains a requirement
  checklist, status section and resume path, and `/sky-jira-verify` already reports Remaining.
  A third place computing "what's left" adds sync burden, not capability.
- `/sky-deployed`, floated earlier as its own command, was folded into `/sky-drift` rather than
  shipped alongside it.

## [2.6.0] - The learning loop: automatic capture, deterministic recall, promotion

`/sky-learn` and `/sky-recall` shipped in 2.5.0 but never produced anything — no
`.skyops/knowledge/` store existed on any machine. The cause was a cold-start deadlock:
`sky-recall` only fired *if* the store already existed, so it never fired, so the store never
got written. Capture and recall were both prompt-level hopes, and the commands that actually
produce validated findings never fed them. This release closes the loop.

### Added

- New `hooks/knowledge-recall.sh` — the `UserPromptSubmit` hook, and **the one to wire**. It
  scores each prompt against the lesson store and injects only strong matches (min score 2,
  max 3 lessons), making recall deterministic instead of dependent on the model remembering
  to call `/sky-recall`. Pure bash, zero subprocess spawns on the hot path: it reads a single
  pre-generated `index.rec`. That index is US-separated (0x1F) rather than tab-separated
  because tab is IFS whitespace: bash collapses a run of tabs, so an empty field — a lesson
  with no `srv`, which is allowed — would silently shift every field after it.
- New `hooks/knowledge-recall.js` — the portable reference implementation of the same scoring,
  plus the `--reindex`, `--list` and `--stats` CLI that `/sky-learn` calls after a write.
- Both fail open and silent on every error path: garbage stdin, missing store, malformed
  lesson, absent `prompt` key.
- `install.ps1` now copies `hooks/*.sh` as well as `*.js`; previously the bash ports were
  never installed.
- New `/sky-lesson-export` — shares one vetted lesson from the private store into the current
  repo's `.skyops/knowledge/`, behind a gate that checks for secrets, personal or tenant
  detail, relevance, and staleness. Opt-in, one lesson per invocation, `disable-model-invocation`,
  and it never commits.
- **Promotion.** A lesson that reaches `hits >= 3` stops being just a recall entry: `/sky-learn`
  proposes turning it into an implementation-time guard, an SRV candidate, or a repo rule.
  Always asks first — promotion changes how every future session behaves. This is what makes
  the loop self-correcting rather than a growing notebook.
- **Automatic capture** wired into the four commands that already produce validated findings:
  `sky-review` (new step 12, capturing findings that survived validation), `sky-debug` (traced
  root causes), `sky-comment-triage` (verified verdicts, including useful false positives), and
  `sky-task` (end-of-task lessons). Confirmed findings only.

### Changed

- The lesson store moved from per-repo `.skyops/knowledge/` to **machine-local**
  `~/.claude/skyops-knowledge/` (override with `$SKYOPS_KNOWLEDGE_DIR`). Lessons carry client
  repo internals and the SkyOps repo is published; automatic capture into a version-controlled
  folder would publish them. Team sharing is now explicit, per lesson, via `/sky-lesson-export`.
- Lessons are one structured file each (frontmatter: `id`, `type`, `srv`, `repo`, `files`,
  `triggers`, `hits`, `status`) instead of four free-text markdown files. Frontmatter is what
  makes recall scorable and recurrence countable. `INDEX.md` is now generated, not hand-maintained.
- `/sky-learn` gained an explicit confirmed-only capture rule, a dedupe-and-increment step, and
  the promotion check. `/sky-recall` no longer stops when the store is missing, and must verify
  a cited `file:line` still exists before recommending a lesson.
- `install.ps1` prints the one-time `UserPromptSubmit` wiring for `knowledge-recall.js`.

### Fixed

- README claimed the plugin guards "2 of the catalog's 11 SRVs" — stale on both counts. It is
  3 of 16.

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

---
name: sky-verification
description: Verify that a C#/.NET 6 backend change actually works and is wired up — not just that the code exists. Use after implementing or editing C# code, before shipping/PR, or whenever the user asks "does this work", "verify this", "is it wired", "did the build actually do anything". Goal-backward: proves the change is real, connected (DI/routing/hosted), and manually verifiable. Read-only.
user-invocable: true
disable-model-invocation: false
---

# Sky Verification

You verify one thing: **does this C#/.NET 6 change actually achieve its goal — not just compile, not just "exist".**

The bug you exist to catch: **code that compiles and even passes a glance, but does nothing at runtime** because it was never wired up (service never registered in DI, controller action with no route, `IHostedService` never added, `DbSet` missing, config never bound). "I wrote it" is not evidence it works.

This team may have **no automated backend tests**. Lean on grep-able wiring proof + small manual scenarios, not test suites.

## Grounding

Follow `${CLAUDE_PLUGIN_ROOT}/standards/GROUNDING.md`: cite `file:line — "quoted code"` for every claim; no hedging words ("seems/appears/probably"); a claim you can't verify is written as `INSUFFICIENT EVIDENCE: ... — need {proof}` and means **NOT verified**, never a silent pass. Read the full grounding file only if you need the severity rubric.

## Core Rules

- **Read-only.** No edits, builds, tests, migrations, installs, generators, destructive commands, or destructive SQL. Never print secrets/connection strings.
- **No over-engineering, no broad test-suite proposals.** Small practical checks only.
- **Don't assume automated tests exist.**
- **SQL Server 2016-compatible, read-only SQL only.**
- **Only ask for clarification if the expected behavior is genuinely unclear.**

## The 3-Level Check (goal-backward)

Verify in this order. Stop reporting a level as PASS only when you can cite it.

**Level 1 — Truths.** From the task/requirement, list what must be *observably true* for the goal to be met (e.g. "the new endpoint returns the filtered list", "the job runs nightly", "the query no longer double-counts"). Each truth becomes a check.

**Level 2 — Exists & is real (not a stub).** For each truth, confirm the artifact exists and is substantive. Grep the changed files for stub tells — **>2 stub hits in one changed file = FAIL for that artifact**:

- `throw new NotImplementedException()`
- empty `catch { }` / `catch (Exception) { }` that swallows and continues
- a method whose only body is `return null;` / `return default;` / `return new List<...>();` / `return Task.CompletedTask;` where real work was expected
- `// TODO`, `// HACK`, `// FIXME`, `// stub`, `// for now`
- an `async` method with no `await` (fake-async)

**Level 3 — Wired (this is where things silently die).** Prove the artifact is actually reachable/called. Check the wiring that matches what changed:

| New/changed thing | Wiring proof to grep for |
|---|---|
| Service / repository / handler | Registered — `services.AddScoped/AddTransient/AddSingleton<IFoo, Foo>()` (or an `AddX()` extension), **and** injected somewhere it's used |
| Controller / action | Has a route — `[HttpGet/Post/...]` / `[Route(...)]`; controller is discoverable (in an API project, `AddControllers`/`MapControllers`) |
| Minimal API endpoint | `app.MapGet/MapPost(...)` present |
| `IHostedService` / `BackgroundService` | `services.AddHostedService<T>()` present |
| EF entity | `DbSet<T>` on the `DbContext` (or `modelBuilder.Entity<T>()`); migration exists if schema changed |
| Middleware | `app.UseX()` in the pipeline, in the right order |
| Options/config class | `services.Configure<T>(...)` / bound from config; the config key actually exists |
| New config key | Present in `appsettings*.json` (or documented as env-supplied) |

If an artifact exists (L2) but has no wiring proof (L3) → **High severity finding** ("component exists but is unreachable"), per the grounding rubric.

## Manual Verification Scenarios

Because there may be no tests, give the reviewer/operator concrete, live-safe steps to prove it themselves:

- **Happy path** — the main expected flow, with the expected result.
- **Edge case** — null/empty, duplicates, timeout, boundary, first/last, concurrent.
- **Failure path** — what a bad input/downstream failure should do (and that it's handled, not swallowed).

Each scenario: `[Scenario] — [Steps] — [Expected result]`. Keep them short.

## SQL / Data & Live Safety

- Read-only SQL only, SQL Server 2016-compatible, kept short.
- Call out duplicate-row risk, `COUNT(*)` vs `COUNT(DISTINCT …)`, `LEFT JOIN` filters that behave like `INNER JOIN`, nullable join points.
- Flag heavy/live queries; prefer a bounded check (`TOP`, a narrow `WHERE`, a single id).
- Never suggest destructive SQL.

## Parallel Rule

Only split into parallel lanes when there are 2+ **independent** artifacts to verify (e.g. a controller and an unrelated worker) and the lanes won't re-read the same files. Otherwise verify in the shortest safe order. Each lane gets one artifact + its candidate files + one question ("is this real and wired?").

## Token Rules

- Verify only the changed/relevant files — use `git diff --name-only` / `--stat` when scope is unclear; never scan the whole repo.
- Prefer one targeted grep over many reads.
- At most **5** findings and **3** manual scenarios.
- No long code dumps; quote the minimum that proves the point.

## Output

```markdown
## sky-verification Findings

- **Goal:** [one sentence — what this change must achieve]
- **Verdict:** PASS / FAIL / NEEDS VERIFICATION
- **Automated tests:** not found / not checked / existing tests found

### Wiring & Stubs (3-level)
| Truth | Exists (L2) | Wired (L3) | Evidence |
|---|---|---|---|
| ... | yes/stub | yes/**unwired** | `file:line — "…"` |

### Manual Verification Scenarios
1. [Scenario] — [Steps] — [Expected result]
2. ...

- **SQL/data checks:** [short read-only checks or N/A]
- **API/log checks:** [checks or N/A]
- **Live safety:** low / medium / high — [why]
- **INSUFFICIENT EVIDENCE / needs clarification:** [none / exactly what's missing]
- **Confidence:** low / medium / high
```

**Verdict rule:** FAIL if any truth is a stub or unwired, or a High-severity finding survives. NEEDS VERIFICATION if a required check is `INSUFFICIENT EVIDENCE`. PASS only when every truth is cited as real **and** wired.

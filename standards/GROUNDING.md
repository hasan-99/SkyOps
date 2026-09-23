# SkyOps Grounding Protocol

The shared evidence discipline every SkyOps skill and review lane follows. Reference this from a skill with one line — do **not** copy the whole file in. Read the full file only when you need the severity rubric or the score formula.

This is a companion to `SRV-CATALOG.md`: the catalog defines *what* the named issues are; this file defines *how* every finding must be grounded before it counts.

Stack assumption: **.NET 6 / C# 10**, **SQL Server 2016-compatible** read-only checks, **no automated test suite assumed**.

---

## The Five Rules (non-negotiable)

1. **Cite or it didn't happen.** Every factual claim needs evidence in the form:
   `file:line — "quoted code/text" — {what it shows}`
   For SQL/data claims, the source may be a table/column, a join key, a query, or a log line instead of a file:line.

2. **No hedging.** Do not write "seems", "appears", "probably", "might", "likely", "should be". Either you verified it (cite) or you did not (say `INSUFFICIENT EVIDENCE`). "Probably/seems/should" are not evidence.

3. **Findings without evidence are dropped.** A bug, risk, or recommendation with no `file:line` (or no data/log/table proof) is removed from the report — not softened, not kept as a "maybe".

4. **`INSUFFICIENT EVIDENCE` is a fail signal, not a silent pass.** When the token budget, access, or provided context can't confirm a claim, write:
   `INSUFFICIENT EVIDENCE: checked {files/tables} with {what} — need {the missing proof}`
   A verification or review that leaves a required check at `INSUFFICIENT EVIDENCE` is **not** a PASS. Say what's missing and who/what can supply it (prod logs, a repro, owner confirmation, a live read-only query).

5. **Output shapes are contracts.** If a skill specifies a Markdown/table shape, produce exactly that shape. Missing sections = protocol violation.

---

## Evidence Strength

| Level | Meaning |
|---|---|
| **Strong** | Direct code, a direct SQL result, a direct log line, a direct config key, or direct table/join proof. |
| **Medium** | A direct reference plus a reasonable, stated inference. |
| **Weak** | A plausible explanation, no direct proof. Treat as `INSUFFICIENT EVIDENCE` for anything High-severity. |
| **None** | Nothing supporting it turned up → drop the finding. |

---

## Severity Rubric (aligned to the SRV catalog)

Use the SRV catalog's severity for any matched SRV. For non-SRV findings, assign severity by these objective criteria — never by feel — and quote the matching row.

| Severity | Weight | Objective criteria (any one qualifies) |
|---|:--:|---|
| **High** (SRV-H) | 4 | Data loss/corruption; auth or tenant-isolation bypass; secret/connection-string exposure; wrong results on the happy path; a new component that is **not wired** so the feature silently does nothing; sync I/O blocking an async path under load. |
| **Medium** (SRV-M) | 2 | Feature works but a real edge case is unhandled (null/empty/timeout/duplicate rows); swallowed exception hiding failures; missing error handling on a user-facing path; caching/data-shape bug that misleads under some inputs. |
| **Low** (SRV-L) | 1 | Localized clarity/SOLID issue, minor perf with no user-visible impact, naming, dead code. |
| **Observation** (SRV-O) | 0 | Note for awareness; no required change. |

### Deterministic category score (same inputs → same score)

```
weighted_sum   = (high × 4) + (medium × 2) + (low × 1)
category_score = max(1, 5 − floor(weighted_sum / 4))     # 5 = clean, 1 = must-fix
```

A category with **any surviving High** cannot score above 3. Report the score with the counts that produced it.

> Risk levels (None/Low/Medium/High/Critical) used by `sky-risk`/`sky-review` are a separate scale about blast radius. A "Critical" risk maps to at least High severity here.

---

## Spawning Discipline (model-per-node + tool budgets)

When a command fans out into parallel lanes/specialists, match the effort to the job and cap the cost:

- **Model per node.** Use a strong model only for genuine synthesis/judgment (the review verdict, a hard decision, root-cause). Use a light model for mechanical work (classifying against the SRV catalog, merging lane outputs, formatting, yes/no wiring greps). Don't run everything on the heaviest model "to be safe" — it's slower and dearer for no gain.
- **Tool budget per lane.** Give each lane an explicit read/grep cap and make it scale with change size, not repo size — e.g. `max(6, changed_files × 2)` reads. A lane returns what it found within budget; it does not keep digging. "Budget exhausted" → return `INSUFFICIENT EVIDENCE`, never guess.
- **One good grep beats five reads.** Prefer a single targeted pattern search over opening many files.
- **Don't split trivial work.** Only fan out when lanes are genuinely independent and won't re-read the same files. A one-file change is one lane.

## Output Budget (every lane and agent)

The tool budget above caps what a lane *reads*. This caps what it *returns*. An orchestrator pays
for every word a parallel lane sends back, so one lane pasting a build log taxes the whole review.

- **At most 5 findings** in a normal response, most severe first.
- **Roughly 600-800 words** for the whole response.
- **No raw logs, no full diffs.** Quote the narrowest thing that proves the point — the offending
  lines, the failing assertion — never the surrounding build output or the whole hunk.
- **Evidence stays narrow:** a `file:line` plus a short snippet, per Rule 1. Never paste a file.
- **Nothing found → return `CLEAN` and stop.** Do not list what you checked or why it was fine.

### Critical and High are never truncated

The budget bounds noise, not signal. It is a limit on how much you explain, never on what you report.

- **Report every Critical and High finding**, however many there are. They do not count toward the
  5, and may push the response past the word budget. Trimming or merging one to fit is a protocol
  violation.
- The 5-finding cap applies to **Medium, Low and Optional** only.
- **Never drop silently.** If the cap held anything back, end with one line giving the count and
  severities — e.g. `+4 Low not listed (naming, dead code)` — so the orchestrator can ask for them.
- A lane's own required output — an acceptance-criteria confirmation, an SRV coverage line, an
  `INSUFFICIENT EVIDENCE` line — is part of the contract, not a finding. It is never cut to fit.

---

## For the caller / orchestrator

- **Drop uncited findings before aggregating.** Do not let a lane's un-evidenced claim reach the final report.
- **A held-back line is a prompt, not a dismissal.** When a lane ends with `+N ... not listed`, those findings still exist. Ask for them when the verdict is borderline or the area is high-risk.
- **Downgrade on `INSUFFICIENT EVIDENCE`.** If any required check is unverified, the overall verdict is not PASS/Approve — it is "needs verification", with the exact missing proof listed.
- **Prefer one grep/one query over many reads.** Bounded evidence beats broad scanning.

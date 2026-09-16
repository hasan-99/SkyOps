# Sky Task — execution engine

Read this only AFTER the user has typed `APPROVE PLAN`.
During the PLAN stage none of it applies.

## Execution Engine (after `APPROVE PLAN`)

Follow the plan file exactly. Before touching code, ensure the branch exists per repo: create `HJ/<KEY>_<desc>` off the latest dev in every repo the plan changes (per project default). Set plan Status to `EXECUTING (phase 1)`.

Run this loop **for each phase, in order**:

### 1. Implement the phase
- If the phase has multiple waves, dispatch one implementation agent per wave **in parallel** (single batch); each wave gets only its steps, its files, and its SRV subset. If steps in different waves would touch the same file, they are not independent collapse them into one wave.
- Write to the SRV watchlist as you code. Follow existing patterns. Keep changes minimal and inside the phase's declared scope.
- When the phase's code is complete, set each requirement it covers to **Implemented** in the Requirement Status table (not Verified the gate has not run yet).
- Do not start the next phase until this phase's gate passes.

### 2. Run the phase verification gate (adaptive to depth)
After all waves complete, verify the phase diff (only the files this phase changed). Run the checks as parallel lanes, each scoped to the phase diff + the phase's requirement subset + relevant SRV files. **The gate depth scales with the plan's planning depth**, but the mandatory safety checks (requirement coverage, unauthorized-change / blast-radius, and the SRVs relevant to the changed code) are enforced at **every** depth never skip them because a task is Tiny.

**Tiny lightweight, token-efficient:**
1. **Requirement coverage** verdict Match / Mismatch / Missing with file:line evidence for the requirements this phase covers (`/sky-jira-verify` spirit).
2. **Blast radius (scoped)** flag any file changed that the plan did not authorize; confirm the phase's declared blast-radius items. No broad repo-wide regression sweep.
3. **SRV (relevant only)** self-check only the SRVs that apply to the changed code, not the full catalogue.
4. **Minimum build/test/manual** the smallest relevant signal: build the affected project if quick, run an existing touching test, or one `/sky-verification` manual check.
   Avoid repeated analysis, redundant reports, and sweeps of unchanged areas.

**Standard the normal gate:**
1. **Requirement coverage** with evidence.
2. **SRV self-check** the phase diff against the phase's SRV watchlist (`review-standards` / `/sky-review` logic).
3. **Blast radius / regression** confirm bystanders behave as declared; flag any unauthorized change.
4. **Build / tests / manual** build affected project(s); run touching tests (optionally via `dotnet6-test-runner`); else define and run `/sky-verification` manual/SQL/live-safe checks.

**Deep Standard plus stronger verification for high-risk/broad change:**
- Broader dependency/regression review around impacted **contracts, APIs, data flows, and consumers** (including other repos that consume the same contract).
- Explicit validation of indirect and runtime blast-radius items, not just direct edits.
- Extra attention to migrations, backward compatibility, tenant/security boundaries, failure paths, and integration behavior.
- Still scoped and evidence-driven: verify impacted surfaces, do not re-review unchanged areas to burn tokens.

Each lane returns a short verdict + evidence. Keep signal over noise at every depth.

### 3. Auto-fix gaps (bounded by max-fix)
If the gate finds any Mismatch, Missing, SRV violation, regression, or failed build/check:
- Apply the **smallest safe fix** for each gap, staying within the phase's scope and SRVs.
- Re-run only the failed gate lanes on the new diff.
- Repeat up to the effective **`max-fix`** rounds recorded in Meta (default `2`, hard max `3`). The limit is **per phase** each phase gets its own fresh budget.
- **Stop immediately regardless of remaining rounds** if fixing a gap would require widening scope beyond the phase's declared blast radius, weakening a security or tenant rule, changing a business rule, or otherwise diverging from the approved plan. Also stop if gaps remain after the `max-fix` rounds are exhausted.
- On stop: set Status to `BLOCKED`, set the affected requirement(s) to **Blocked**, record the gap and why in the Execution Log, and ask the user one focused question. Never silently widen scope, weaken a security/tenant rule, or paper over a failing check.

### 4. Record and advance
- Only after the gate **passes**, set the phase's covered requirements to **Verified** in the Requirement Status table, each with concise evidence (file:line, test, or check). A requirement never reaches Verified on code change alone.
- Mark the phase `[x] done`, fill its **Gate result**, and append to the Execution Log (what was built, gate verdicts, gaps, fixes).
- Update Status to the next phase and continue.

### Final verification (after the last phase)
Run one full-task pass across **all** phases combined, at a depth matching the plan (Deep gets the broader dependency/regression review):
- Full requirement coverage: every `R` id has a final Match verdict with evidence.
- Full SRV self-check on the complete diff.
- Full-task build + tests/manual verification + blast-radius regression sweep.

**Completion gate:** confirm **every** requirement in the Requirement Status table is `Verified`. If any requirement is still `Planned`, `Implemented`, or `Blocked`, **do not report success** set Status to `BLOCKED` (or leave `EXECUTING`), list the not-yet-Verified requirements with why, and stop for user input. Only when all requirements are `Verified` do you fill **Final Verification** and set Status to `DONE`.

### Guardrails during execution
- Never commit, push, or post to Jira on your own. Follow the ask-before-push-and-post rule and request explicit per-action permission. Report the diff and let the user drive git.
- Keep the plan file current after every phase so the task survives context compaction.
- Stay inside the approved scope. New scope discovered mid-execution goes to the Execution Log and to the user, not silently into the code.

---

## Resume

If a plan file already exists for the key, read it and continue from its Status:
- `PLANNING` / `AWAITING APPROVAL` finish planning and re-present for approval.
- `EXECUTING (phase N)` / `VERIFYING (phase N)` re-scope to phase N: check what is already changed on the branch, run the phase gate, and continue the loop. Do not redo completed, gate-passed phases.
- `BLOCKED` show the recorded blocker and the pending question; wait for the answer, then continue.
- `DONE` say so and offer to re-run final verification only.

Same key + same branch means resume, not restart. Never overwrite a plan file with a fresh one without the user's say-so.

---

## Verification Frameworks Available

Use any that fit the phase, and add a new check if none covers the risk:
- **Requirement traceability** `/sky-jira-verify` logic Match/Mismatch/Missing per requirement, evidence required.
- **SRV defect review** `review-standards` skill / `/sky-review` classify the diff against the SRV catalogue.
- **Manual / SQL / live-safe** `/sky-verification` practical read-only checks, happy path, edge cases, rollback confirmation.
- **Automated tests** `dotnet6-test-runner` agent author and run focused tests for changed .NET 6 code.
- **Build** compile the affected project(s) as the first cheap regression signal.
- **End-to-end drive** the `/verify` skill when a phase has a runtime surface worth exercising, not just tests.

Scope every framework to the phase diff. Never run a whole-repo sweep when the phase diff is enough.

---


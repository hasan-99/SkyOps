#!/usr/bin/env bash
# One-shot maintenance script: rewrite the frontmatter `description:` line of every
# model-invocable asset to the gated, <=160-char form.
#
# Why this exists: a description is the ONLY thing the model sees before deciding to
# auto-invoke a skill, and it is paid in every session's system prompt. Long
# descriptions cost tokens forever; ungated ones make orchestrator internals fire on
# their own. Both are fixed in the same line of text.
#
# Idempotent. Rewrites only the first `description:` line inside the frontmatter.
set -u
cd "$(dirname "$0")/.." || exit 1

apply() {
  local file=$1 desc=$2
  [[ -f $file ]] || { echo "  MISSING $file"; return; }
  local len=${#desc}
  if (( len > 160 )); then echo "  TOO LONG ($len) $file"; return; fi
  awk -v d="description: $desc" '
    /^---$/ { c++ }
    c==1 && /^description:/ && !done { print d; done=1; next }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  echo "  ok ($len) $file"
}

S=skills; C=commands

# --- orchestrator internals: must stay invocable (their parent calls them by name)
#     but the description tells the model not to start them on its own.
apply $S/review-standards/SKILL.md \
 "Internal lane of /sky-review and /sky-task. Maps a finding to its SRV code and severity. Do not invoke on its own."
apply $S/sky-review-context/SKILL.md \
 "Internal lane of /sky-review. Resolves the Jira requirement, criteria, comments, repos and branches. Do not invoke on its own."
apply $S/sky-review-scope/SKILL.md \
 "Internal lane of /sky-review. Builds the exact changed-file and changed-method scope for a ticket. Do not invoke on its own."
apply $S/sky-review-flow/SKILL.md \
 "Internal lane of /sky-review. End-to-end integration check across the touched layers. Do not invoke on its own."
apply $S/sky-review-finalize/SKILL.md \
 "Internal lane of /sky-review. Formats the final report and the paste-ready Jira comment. Do not invoke on its own."
apply $S/sky-change-summary/SKILL.md \
 "Internal. Summarises the current git change from diff stats. Called by /sky-pr and workflow reports, not on its own."

# --- workflow bodies: run via /sky-* or sky-dispatch, never spontaneously.
apply $S/sky-workflow-task/SKILL.md \
 "Workflow body for /sky-task: durable plan file, APPROVE PLAN gate, phased execution. Started by sky-dispatch or /sky-task only."
apply $S/sky-workflow-fast/SKILL.md \
 "Workflow body for /sky-fast: small localized change, compact plan, APPROVE PLAN gate. Started by sky-dispatch or /sky-fast only."
apply $S/sky-workflow-debug/SKILL.md \
 "Workflow body for /sky-debug: trace to root cause, check impact, propose a fix, APPROVE PLAN gate. Started by sky-dispatch only."
apply $S/sky-workflow-test/SKILL.md \
 "Workflow body for /sky-test: map the change to covering tests, write them xUnit+NSubstitute style, run only those."

# --- advisory skills: genuinely useful to auto-fire, kept short.
apply $S/sky-decision/SKILL.md \
 "Compare options for backend, SQL or review work: tradeoffs, risk, effort, and the safest next step."
apply $S/sky-risk/SKILL.md \
 "Before a backend, SQL or production change: what can break, risk level, mitigation, rollback."
apply $S/sky-evidence/SKILL.md \
 "Check that each claim in a report is backed by proof from this session; flag unverified assertions."
apply $S/sky-verification/SKILL.md \
 "Plan read-only verification of a backend change: SQL checks, API checks, acceptance criteria."
apply $S/sky-memory-sync/SKILL.md \
 "Update ticket memory right after a state change: committed, pushed, posted, merged, or a stored fact proven stale."

# --- the router.  Keeps its trigger phrases: they are what make it fire correctly.
apply $S/sky-dispatch/SKILL.md \
 "Route a plain-language ticket request to the right workflow and run it. Fires on work on / fix / why is / continue CLS-1234."

# --- user-facing commands that are also model-invocable.
apply $C/sky-comment-triage.md \
 "Validate a reviewer's Jira or PR comment against the real code, size the fix, and draft the reply. Read-only."
apply $C/sky-jira-verify.md \
 "Check the branch changes against every Jira requirement and report Match, Mismatch, Remaining, Suggestions."
apply $C/sky-memory.md \
 "Inspect, file, age or archive Claude's memory store; search archived ticket history; audit for stale entries."
apply $C/sky-async-guard.md \
 "Fires on new async code: checks every DB/HTTP/file call is truly async and a CancellationToken is threaded (SRV-H-001, L-010)."
apply $C/sky-i18n-guard.md \
 "Fires on new DateTime or numeric Parse/ToString: checks InvariantCulture and explicit styles (SRV-H-006)."
apply $C/sky-sql-destructive-guard.md \
 "Fires on new destructive SQL (DROP, TRUNCATE, DELETE/UPDATE without WHERE, dropped tenant filter). Flags the safe alternative."
apply $C/sky-doctor.md \
 "Deep read-only diagnostic of SkyOps setup, installed assets, hook wiring and repo readiness. Run on request."
apply $C/sky-health.md \
 "Quick read-only check of SkyOps setup, Git state and project type. Run on request."
apply $C/sky-map.md \
 "Build a compact architecture map of a C#/.NET repo: projects, layers, key files, Mermaid diagram. Run on request."

echo "done."

#!/usr/bin/env bash
# SkyOps PreToolUse dispatcher (bash) — Bash tool calls.
#
# One process per Bash tool call instead of one per guard. Previously
# settings.json wired sql-guard.sh and git-guard.sh as two separate PreToolUse
# entries, so every Bash call paid two ~0.75s spawns. This reads stdin once and
# SOURCES both guards, calling them in-process.
#
# Sourcing, not sub-shelling: measured on this machine, exec 0.75s, subshell
# fork 0.43s, command substitution 0.29s, sourced call ~0s. A dispatcher that
# forked its children would be slower than the two spawns it replaces.
#
# Rules are NOT duplicated here — each guard still owns its own rule set and
# still runs standalone when executed directly. Order matches the original
# settings.json entry order: SQL first, then git.
#
# Behaviour preserved: decision is "ask", never a hard block; exit code is
# always 0; any failure falls back to allowing the command (fail-open), because
# a guard that breaks the pipeline is worse than one that misses a case.

# Fail open, always. No `set -e`: a non-zero from any check must never abort the
# hook and block the user's tool call.
# Resolve our own directory, tolerating BOTH separators. A hook command may name
# this file as C:\...\guard-dispatch.sh or C:/.../guard-dispatch.sh, and ${x%/*}
# returns x unchanged when there is no forward slash — which silently pointed the
# source lookups at a non-existent directory and made every guard a no-op while
# still exiting 0. A guard that quietly stops guarding is the worst failure here,
# so normalise first and verify the guards actually loaded (see GUARDS below).
SKYOPS_SELF=${BASH_SOURCE[0]//\\//}
SKYOPS_DIR=${SKYOPS_SELF%/*}
[ "$SKYOPS_DIR" = "$SKYOPS_SELF" ] && SKYOPS_DIR=.

# shellcheck source=/dev/null
[ -r "$SKYOPS_DIR/metrics.sh" ] && . "$SKYOPS_DIR/metrics.sh"
type skyops_metric >/dev/null 2>&1 || { skyops_metric() { :; }; skyops_metric_start() { :; }; skyops_metric_ms() { SKYOPS_MS=0; }; }
skyops_metric_start

# Read stdin once (no fork).
RAW=''
if [ ! -t 0 ]; then IFS= read -r -d '' RAW; fi

SQL_REASON=''
GIT_REASON=''

# Source each guard and call it. If a guard file is missing or unreadable we
# skip that guard rather than aborting — the other still runs.
GUARDS=0
if [ -r "$SKYOPS_DIR/sql-guard.sh" ]; then
  # shellcheck source=/dev/null
  . "$SKYOPS_DIR/sql-guard.sh" && { sql_guard_decide "$RAW"; GUARDS=$((GUARDS + 1)); }
fi
if [ -r "$SKYOPS_DIR/git-guard.sh" ]; then
  # shellcheck source=/dev/null
  . "$SKYOPS_DIR/git-guard.sh" && { git_guard_decide "$RAW"; GUARDS=$((GUARDS + 1)); }
fi

# Merge, SQL first, matching the original entry order. Both guards asking ->
# one "ask" carrying both blocks; a single hook emits a single decision, and
# "ask" + "ask" was already "ask".
REASON=''
if [ -n "$SQL_REASON" ] && [ -n "$GIT_REASON" ]; then
  REASON="$SQL_REASON"$'\n\n'"$GIT_REASON"
elif [ -n "$SQL_REASON" ]; then
  REASON=$SQL_REASON
elif [ -n "$GIT_REASON" ]; then
  REASON=$GIT_REASON
fi

skyops_metric_ms
if [ -n "$REASON" ]; then
  skyops_metric kind=hook hook=guard-dispatch event=PreToolUse tool=Bash \
    "ms=$SKYOPS_MS" decision=ask impl=bash "guards=$GUARDS"
else
  skyops_metric kind=hook hook=guard-dispatch event=PreToolUse tool=Bash \
    "ms=$SKYOPS_MS" decision=allow impl=bash "guards=$GUARDS"
fi

[ -z "$REASON" ] && exit 0

# emit_ask comes from whichever guard was sourced last; both define it
# identically (verified byte-identical), so either is correct.
if type emit_ask >/dev/null 2>&1; then
  emit_ask "$REASON"
fi
exit 0

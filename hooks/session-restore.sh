#!/usr/bin/env bash
# SkyOps SessionStart hook (bash) — reconnect to active work after a compaction.
# Bash port of session-restore.js; behaviour intentionally identical.
#
# WRITES NOTHING. SkyOps already persists what a compacted session needs:
#   plans/<KEY>.plan.md          phase (Meta Status), Requirement Status table
#   .skyops/scope/<x>.scope.md   key, branch, base, head_sha, repos, files
# What was missing is the reconnect, not the state. This emits pointers only —
# no checkpoint, no duplication, and nothing that can go stale, because branch
# and HEAD are read live and the manifest is judged against HEAD right now.
#
# Silent unless there is genuinely active work. Any error => exit 0, no output:
# a restore hint must never break a session.
#
# Why bash: a node spawn costs ~7.3s here against ~0.75s for bash (measured).
# The three `git` calls below are forks, but this fires once per compaction.

RAW=''
if [ ! -t 0 ]; then IFS= read -r -d '' RAW; fi

# Tolerate both path separators — see guard-dispatch.sh for why.
SKYOPS_SELF=${BASH_SOURCE[0]//\\//}
SKYOPS_DIR=${SKYOPS_SELF%/*}
[ "$SKYOPS_DIR" = "$SKYOPS_SELF" ] && SKYOPS_DIR=.
# shellcheck source=/dev/null
[ -r "$SKYOPS_DIR/metrics.sh" ] && . "$SKYOPS_DIR/metrics.sh"
type skyops_metric >/dev/null 2>&1 || skyops_metric() { :; }

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  JE=$s
}

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -z "$REPO_ROOT" ] && exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)

# Ticket key from the branch name, e.g. HJ/CLS-15480-alerts -> CLS-15480.
KEY=''
if [[ $BRANCH =~ ([A-Z][A-Z0-9]+-[0-9]+) ]]; then KEY=${BASH_REMATCH[1]}; fi

# --- plan file ---------------------------------------------------------------
PLANS_DIR=''
for d in "${SKYOPS_PLANS_DIR:-}" "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/plans}" "$SKYOPS_DIR/../plans"; do
  [ -n "$d" ] && [ -d "$d" ] && { PLANS_DIR=$d; break; }
done

PLAN_PATH=''
[ -n "$PLANS_DIR" ] && [ -n "$KEY" ] && [ -f "$PLANS_DIR/$KEY.plan.md" ] && PLAN_PATH="$PLANS_DIR/$KEY.plan.md"

LINES=''
PLAN_STATUS=''
OPEN=-1
HAD_PLAN=false
if [ -n "$PLAN_PATH" ]; then
  HAD_PLAN=true
  in_section=0
  seen=0
  open=0
  while IFS= read -r line || [ -n "$line" ]; do
    # Meta status line: - **Status:** EXECUTING (phase 2)
    if [ -z "$PLAN_STATUS" ] && [[ $line =~ ^[[:space:]]*-[[:space:]]*\*\*Status:\*\*[[:space:]]*(.+)$ ]]; then
      PLAN_STATUS=${BASH_REMATCH[1]}
    fi
    # Requirement Status section only — the spine table has a different shape.
    if [ $in_section -eq 0 ]; then
      case $line in '## Requirement Status'*) in_section=1 ;; esac
      continue
    fi
    case $line in '## '*) in_section=2 ;; esac
    [ $in_section -eq 2 ] && continue
    case $line in '|'*) ;; *) continue ;; esac
    IFS='|' read -ra cells <<< "$line"
    [ ${#cells[@]} -lt 5 ] && continue
    id=${cells[1]//[[:space:]]/}
    [[ $id =~ ^R[0-9]+$ ]] || continue
    st=${cells[4]}
    st=${st//[\*\`_]/}          # strip **bold**, `code`, _emphasis_
    st=${st#"${st%%[![:space:]]*}"}
    seen=$((seen + 1))
    case ${st,,} in
      verified*) ;;
      *) open=$((open + 1)) ;;
    esac
  done < "$PLAN_PATH"
  [ $seen -gt 0 ] && OPEN=$open

  LINES="- plan: $PLAN_PATH"
  [ -n "$PLAN_STATUS" ] && LINES="$LINES (Status: $PLAN_STATUS)"
  if [ $OPEN -lt 0 ]; then
    LINES="$LINES"$'\n'"- open requirements: unknown (no Requirement Status table)"
  elif [ $OPEN -gt 0 ]; then
    LINES="$LINES"$'\n'"- open requirements: $OPEN not yet Verified"
  else
    LINES="$LINES"$'\n'"- open requirements: none — all Verified"
  fi
fi

# --- scope manifest, freshness judged against HEAD right now -----------------
SCOPE_DIR=${SKYOPS_SCOPE_DIR:-$REPO_ROOT/.skyops/scope}
SCOPE_PATH=''
if [ -d "$SCOPE_DIR" ]; then
  if [ -n "$KEY" ]; then
    for f in "$SCOPE_DIR"/*"$KEY"*.scope.md; do
      [ -e "$f" ] && { SCOPE_PATH=$f; break; }
    done
  fi
  if [ -z "$SCOPE_PATH" ] && [ -n "$BRANCH" ]; then
    slug=${BRANCH//[^A-Za-z0-9.-]/-}
    for f in "$SCOPE_DIR"/*"$slug"*.scope.md; do
      [ -e "$f" ] && { SCOPE_PATH=$f; break; }
    done
  fi
fi

SCOPE_STATE=absent
if [ -n "$SCOPE_PATH" ]; then
  SHA=''
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^head_sha:[[:space:]]*([^[:space:]]+) ]]; then SHA=${BASH_REMATCH[1]}; break; fi
  done < "$SCOPE_PATH"
  if [ -n "$SHA" ] && [ -n "$HEAD_SHA" ]; then
    if [ "$SHA" = "$HEAD_SHA" ]; then
      SCOPE_STATE=reused
      FRESH="current"
    else
      SCOPE_STATE=stale
      FRESH="STALE (captured at ${SHA:0:8}, HEAD is ${HEAD_SHA:0:8}) — re-run /sky-scope before trusting it"
    fi
  else
    SCOPE_STATE=unknown
    FRESH="freshness unknown"
  fi
  [ -n "$LINES" ] && LINES="$LINES"$'\n'
  LINES="$LINES- scope manifest: $SCOPE_PATH — $FRESH"
fi

skyops_metric kind=compaction event=SessionStart source=compact \
  "had_plan=$HAD_PLAN" "scope_manifest=$SCOPE_STATE" "open_requirements=$OPEN" impl=bash

# Meaningful active work only. Nothing found => say nothing at all.
[ -z "$LINES" ] && exit 0

CTX="SkyOps active work (restored after compaction — pointers only, all state lives in these files):
- ticket: ${KEY:-(none in branch name)}
- repo: ${REPO_ROOT##*/}   branch: ${BRANCH:-(unknown)}   HEAD: ${HEAD_SHA:0:8}
$LINES
Read the plan file before continuing the task; it is the source of truth for phase and remaining work.
Re-verify branch, working tree, and test/build state in this session — do not trust anything above as current beyond the live git values."

json_escape "$CTX"
printf '%s' "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"$JE\"}}"
exit 0
